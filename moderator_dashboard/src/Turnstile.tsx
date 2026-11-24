import { useEffect, useId, useRef } from "react";

declare global {
  interface Window {
    turnstile?: {
      render: (
        element: string | HTMLElement,
        options: {
          sitekey: string;
          callback: (token: string) => void;
          "expired-callback"?: () => void;
          "error-callback"?: () => void;
          theme?: "light" | "dark" | "auto";
        },
      ) => string;
      reset: (widgetId: string) => void;
      remove: (widgetId: string) => void;
    };
  }
}

type TurnstileProps = {
  siteKey: string;
  onToken: (token: string | null) => void;
};

export function Turnstile({ siteKey, onToken }: TurnstileProps) {
  const elementId = useId().replace(/:/g, "");
  const widgetIdRef = useRef<string | null>(null);
  const onTokenRef = useRef(onToken);
  onTokenRef.current = onToken;

  useEffect(() => {
    let cancelled = false;
    let attempts = 0;

    const tryRender = () => {
      if (cancelled) return;
      const host = document.getElementById(elementId);
      if (!host || !window.turnstile) {
        attempts += 1;
        if (attempts < 40) {
          window.setTimeout(tryRender, 100);
        }
        return;
      }

      if (widgetIdRef.current) {
        window.turnstile.remove(widgetIdRef.current);
        widgetIdRef.current = null;
      }

      host.innerHTML = "";
      widgetIdRef.current = window.turnstile.render(host, {
        sitekey: siteKey,
        callback: (token) => onTokenRef.current(token),
        "expired-callback": () => onTokenRef.current(null),
        "error-callback": () => onTokenRef.current(null),
        theme: "light",
      });
    };

    tryRender();

    return () => {
      cancelled = true;
      if (widgetIdRef.current && window.turnstile) {
        window.turnstile.remove(widgetIdRef.current);
        widgetIdRef.current = null;
      }
    };
  }, [elementId, siteKey]);

  if (!siteKey) {
    return (
      <p className="muted">
        Set VITE_TURNSTILE_SITE_KEY to enable captcha for OTP requests.
      </p>
    );
  }

  return <div id={elementId} className="turnstile-host" />;
}

export function resetTurnstile(hostElementId?: string) {
  if (!window.turnstile) return;
  // Widgets are managed by the component lifecycle; callers usually remount.
  void hostElementId;
}
