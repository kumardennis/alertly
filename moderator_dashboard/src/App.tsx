/* eslint-disable react-hooks/set-state-in-effect */
import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { createClient, type Session } from "@supabase/supabase-js";
import "./App.css";

type AlertStatus =
  | "pending"
  | "published"
  | "rejected"
  | "resolved"
  | "expired";

type AlertRow = {
  id: number;
  title: string | null;
  body: string | null;
  category: string | null;
  status: AlertStatus;
  flagged: boolean | null;
  created_at: string;
  user_id: number | null;
  user?: {
    id: number;
    username: string;
  } | null;
};

const API_BASE = import.meta.env.VITE_API_BASE?.trim() ?? "";
const DEFAULT_SUPABASE_URL = "https://vebbrghiubfssxucqbfq.supabase.co";
const DEFAULT_SUPABASE_PUBLISHABLE_KEY =
  "sb_publishable_msTXazQTkrFOHg1wLQ-x6w_UKOqP6v4";
const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL?.trim() || DEFAULT_SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ||
  DEFAULT_SUPABASE_PUBLISHABLE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [otpRequested, setOtpRequested] = useState(false);
  const [authLoading, setAuthLoading] = useState(false);
  const [statusFilter, setStatusFilter] = useState<AlertStatus>("pending");
  const [flaggedOnly, setFlaggedOnly] = useState(false);
  const [alerts, setAlerts] = useState<AlertRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busyAlertId, setBusyAlertId] = useState<number | null>(null);

  useEffect(() => {
    let mounted = true;

    void supabase.auth.getSession().then(({ data }) => {
      if (mounted) {
        setSession(data.session);
      }
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  const canLoadQueue = useMemo(
    () => Boolean(session?.access_token?.trim()),
    [session],
  );

  const normalizedPhone = useMemo(() => {
    const trimmed = phone.trim();
    if (!trimmed) return "";
    if (trimmed.startsWith("+")) return trimmed;
    return `+${trimmed}`;
  }, [phone]);

  const loadQueue = useCallback(async () => {
    if (!canLoadQueue || !session?.access_token) {
      setAlerts([]);
      setError("Sign in to load the moderation queue.");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams({
        status: statusFilter,
        flagged: String(flaggedOnly),
        limit: "100",
      });

      const response = await fetch(
        `${API_BASE}/api/alerts/moderation/queue?${params.toString()}`,
        {
          headers: {
            Authorization: `Bearer ${session.access_token}`,
          },
        },
      );

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload?.error ?? "Failed to load moderation queue");
      }

      setAlerts((payload?.alerts as AlertRow[]) ?? []);
    } catch (caughtError) {
      const message =
        caughtError instanceof Error
          ? caughtError.message
          : "Failed to load moderation queue";
      setError(message);
    } finally {
      setLoading(false);
    }
  }, [canLoadQueue, flaggedOnly, session, statusFilter]);

  useEffect(() => {
    if (!canLoadQueue) {
      return;
    }

    void loadQueue();
  }, [canLoadQueue, loadQueue]);

  const requestOtp = async (event: FormEvent) => {
    event.preventDefault();

    if (!normalizedPhone) {
      setError(
        "Enter a phone number in E.164 format, for example +37255123456.",
      );
      return;
    }

    setAuthLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE}/api/auth/register`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          phone: normalizedPhone,
          channel: "sms",
        }),
      });

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload?.error ?? "Failed to send OTP");
      }

      setOtpRequested(true);
    } catch (caughtError) {
      const message =
        caughtError instanceof Error
          ? caughtError.message
          : "Failed to send OTP";
      setError(message);
    } finally {
      setAuthLoading(false);
    }
  };

  const verifyOtp = async (event: FormEvent) => {
    event.preventDefault();

    const code = otp.trim();
    if (code.length !== 6 || !normalizedPhone) {
      setError("Enter the 6-digit OTP code.");
      return;
    }

    setAuthLoading(true);
    setError(null);

    try {
      const { error: verifyError } = await supabase.auth.verifyOtp({
        phone: normalizedPhone,
        token: code,
        type: "sms",
      });

      if (verifyError) {
        throw new Error(verifyError.message);
      }

      setOtp("");
    } catch (caughtError) {
      const message =
        caughtError instanceof Error
          ? caughtError.message
          : "Failed to verify OTP";
      setError(message);
    } finally {
      setAuthLoading(false);
    }
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setAlerts([]);
    setOtpRequested(false);
    setOtp("");
    setError(null);
  };

  const reviewAlert = async (alertId: number, status: AlertStatus) => {
    if (!session?.access_token) return;

    setBusyAlertId(alertId);
    setError(null);

    try {
      const response = await fetch(`${API_BASE}/api/alerts/review`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          alertId: String(alertId),
          status,
          flagged: status === "rejected",
        }),
      });

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload?.error ?? "Review action failed");
      }

      setAlerts((prev) => prev.filter((alert) => alert.id !== alertId));
    } catch (caughtError) {
      const message =
        caughtError instanceof Error
          ? caughtError.message
          : "Review action failed";
      setError(message);
    } finally {
      setBusyAlertId(null);
    }
  };

  const userPhone = session?.user.phone ?? "Authenticated moderator";

  return (
    <main className="page-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Alertly Ops</p>
          <h1>Moderator Dashboard</h1>
          <p className="helper-text">
            Backend: {API_BASE || "same-origin /api"}
          </p>
        </div>
        {session ? (
          <div className="row">
            <span className="signed-in-pill">{userPhone}</span>
            <button
              type="button"
              className="button ghost"
              onClick={() => void signOut()}
            >
              Sign out
            </button>
            <button
              type="button"
              className="button secondary"
              onClick={() => void loadQueue()}
              disabled={loading || !canLoadQueue}
            >
              {loading ? "Refreshing..." : "Refresh queue"}
            </button>
          </div>
        ) : null}
      </header>

      {!session ? (
        <section className="panel token-panel">
          <h2>Moderator Sign In</h2>
          <p>
            Use the same phone OTP flow as the mobile app. Session is persisted
            automatically.
          </p>

          <form onSubmit={requestOtp} className="auth-form">
            <label>
              Phone (E.164)
              <input
                type="tel"
                value={phone}
                onChange={(event) => setPhone(event.target.value)}
                placeholder="+37255123456"
                autoComplete="tel"
              />
            </label>
            <button
              type="submit"
              className="button primary"
              disabled={authLoading}
            >
              {authLoading ? "Sending..." : "Send OTP"}
            </button>
          </form>

          {otpRequested ? (
            <form onSubmit={verifyOtp} className="auth-form otp-form">
              <label>
                OTP code
                <input
                  type="text"
                  value={otp}
                  onChange={(event) =>
                    setOtp(event.target.value.replace(/\D/g, "").slice(0, 6))
                  }
                  placeholder="123456"
                  inputMode="numeric"
                />
              </label>
              <button
                type="submit"
                className="button secondary"
                disabled={authLoading}
              >
                {authLoading ? "Verifying..." : "Verify OTP"}
              </button>
            </form>
          ) : null}
        </section>
      ) : null}

      {session ? (
        <section className="panel filter-panel">
          <div className="row wrap">
            <label>
              Status
              <select
                value={statusFilter}
                onChange={(event) =>
                  setStatusFilter(event.target.value as AlertStatus)
                }
              >
                <option value="pending">Pending</option>
                <option value="published">Published</option>
                <option value="rejected">Rejected</option>
                <option value="resolved">Resolved</option>
                <option value="expired">Expired</option>
              </select>
            </label>

            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={flaggedOnly}
                onChange={(event) => setFlaggedOnly(event.target.checked)}
              />
              Flagged only
            </label>

            <button
              type="button"
              className="button secondary"
              onClick={() => void loadQueue()}
              disabled={loading || !canLoadQueue}
            >
              Apply filters
            </button>
          </div>
        </section>
      ) : null}

      {error ? <div className="alert error">{error}</div> : null}

      {session ? (
        <section className="cards">
          {alerts.length === 0 ? (
            <div className="empty">
              No alerts found for the current filters.
            </div>
          ) : (
            alerts.map((alert) => (
              <article key={alert.id} className="panel card">
                <div className="card-head">
                  <h3>{alert.title ?? "Untitled alert"}</h3>
                  <span className={`pill ${alert.status}`}>{alert.status}</span>
                </div>
                <p className="body-text">
                  {alert.body ?? "No message provided."}
                </p>
                <div className="meta-grid">
                  <span>
                    <strong>ID:</strong> {alert.id}
                  </span>
                  <span>
                    <strong>Category:</strong> {alert.category ?? "other"}
                  </span>
                  <span>
                    <strong>Reporter:</strong>{" "}
                    {alert.user?.username ??
                      `user_${alert.user_id ?? "unknown"}`}
                  </span>
                  <span>
                    <strong>Created:</strong>{" "}
                    {new Date(alert.created_at).toLocaleString()}
                  </span>
                  <span>
                    <strong>Flagged:</strong> {alert.flagged ? "yes" : "no"}
                  </span>
                </div>

                <div className="row">
                  <button
                    type="button"
                    className="button approve"
                    onClick={() => void reviewAlert(alert.id, "published")}
                    disabled={busyAlertId === alert.id}
                  >
                    Approve
                  </button>
                  <button
                    type="button"
                    className="button reject"
                    onClick={() => void reviewAlert(alert.id, "rejected")}
                    disabled={busyAlertId === alert.id}
                  >
                    Reject
                  </button>
                </div>
              </article>
            ))
          )}
        </section>
      ) : null}
    </main>
  );
}

export default App;
