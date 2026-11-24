import { FastifyInstance } from "fastify";

import { getRedisClient, hasRedisConfig } from "../lib/redis";
import { getSupabaseClient } from "../lib/supabase";
import { createUser, getUser } from "../funtions/userOperations";

type RegisterBody = {
  phone?: string;
  channel?: "sms" | "whatsapp";
};

type VerifyBody = {
  phone?: string;
  token?: string;
};

/** Min gap between OTPs to the same phone. */
const OTP_COOLDOWN_SECONDS = 180;
/** Max OTP sends per client IP inside the IP window. */
const OTP_IP_MAX_REQUESTS = 3;
const OTP_IP_WINDOW_SECONDS = 600;
const ESTONIA_PHONE_RE = /^\+372\d{7,8}$/;

const memoryOtpCooldowns = new Map<string, number>();
const memoryIpBuckets = new Map<string, { count: number; resetAt: number }>();

function normalizePhone(phone: string) {
  const trimmed = phone.trim();
  const digits = trimmed.replace(/[^\d]/g, "");
  if (digits.startsWith("372")) {
    return `+${digits}`;
  }
  if (trimmed.startsWith("+")) {
    return `+${digits}`;
  }
  return digits ? `+${digits}` : "";
}

function clientIp(request: { ip: string; headers: Record<string, unknown> }) {
  const forwarded = request.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.trim()) {
    return forwarded.split(",")[0]?.trim() || request.ip;
  }
  return request.ip;
}

async function claimOtpSendSlot(phone: string): Promise<boolean> {
  const key = `otp:cooldown:${phone}`;

  if (hasRedisConfig()) {
    const result = await getRedisClient().set(
      key,
      "1",
      "EX",
      OTP_COOLDOWN_SECONDS,
      "NX",
    );
    return result === "OK";
  }

  const now = Date.now();
  const expiresAt = memoryOtpCooldowns.get(phone);
  if (expiresAt && expiresAt > now) {
    return false;
  }

  memoryOtpCooldowns.set(phone, now + OTP_COOLDOWN_SECONDS * 1000);
  return true;
}

async function claimOtpIpSlot(ip: string): Promise<boolean> {
  const key = `otp:ip:${ip}`;

  if (hasRedisConfig()) {
    const redis = getRedisClient();
    const count = await redis.incr(key);
    if (count === 1) {
      await redis.expire(key, OTP_IP_WINDOW_SECONDS);
    }
    return count <= OTP_IP_MAX_REQUESTS;
  }

  const now = Date.now();
  const bucket = memoryIpBuckets.get(ip);
  if (!bucket || bucket.resetAt <= now) {
    memoryIpBuckets.set(ip, {
      count: 1,
      resetAt: now + OTP_IP_WINDOW_SECONDS * 1000,
    });
    return true;
  }

  if (bucket.count >= OTP_IP_MAX_REQUESTS) {
    return false;
  }

  bucket.count += 1;
  memoryIpBuckets.set(ip, bucket);
  return true;
}

export default async function authRoutes(app: FastifyInstance) {
  app.post<{ Body: RegisterBody }>("/register", async (request, reply) => {
    const { phone: rawPhone, channel = "sms" } = request.body ?? {};

    if (!rawPhone) {
      return reply.code(400).send({
        error: "phone is required",
      });
    }

    const phone = normalizePhone(rawPhone);
    if (!ESTONIA_PHONE_RE.test(phone)) {
      return reply.code(400).send({
        error: "Only Estonian numbers (+372) are supported.",
      });
    }

    try {
      const ip = clientIp(request);
      const ipAllowed = await claimOtpIpSlot(ip);
      if (!ipAllowed) {
        return reply.code(429).send({
          error:
            "Too many OTP requests from this network. Please wait and try again.",
          retryAfterSeconds: OTP_IP_WINDOW_SECONDS,
        });
      }

      const allowed = await claimOtpSendSlot(phone);
      if (!allowed) {
        return reply.code(429).send({
          error: `Please wait ${OTP_COOLDOWN_SECONDS}s before requesting another code.`,
          retryAfterSeconds: OTP_COOLDOWN_SECONDS,
        });
      }

      const supabase = getSupabaseClient();
      const { error } = await supabase.auth.signInWithOtp({
        phone,
        options: {
          channel,
          shouldCreateUser: true,
        },
      });

      if (error) {
        return reply.code(400).send({
          error: error.message,
        });
      }

      return reply.code(202).send({
        message: "otp sent",
        phone,
      });
    } catch (error) {
      request.log.error(error);

      return reply.code(500).send({
        error: error instanceof Error ? error.message : "unable to send otp",
      });
    }
  });

  app.post<{ Body: VerifyBody }>("/verify", async (request, reply) => {
    const { phone, token } = request.body ?? {};

    if (!phone || !token) {
      return reply.code(400).send({
        error: "phone and token are required",
      });
    }

    try {
      const supabase = getSupabaseClient();
      const { data, error } = await supabase.auth.verifyOtp({
        phone: normalizePhone(phone),
        token,
        type: "sms",
      });

      if (error) {
        return reply.code(400).send({
          error: error.message,
        });
      }

      const authId = data.user?.id;
      if (!authId) {
        return reply
          .code(500)
          .send({ error: "auth user missing after verify" });
      }

      const existingUsers = await getUser({ auth_id: authId });
      let profile = existingUsers[0] ?? null;
      let isNewUser = false;

      if (!profile) {
        isNewUser = true;
        profile = await createUser({
          auth_id: authId,
          username: "",
        });
      }

      return reply.send({
        message: "phone verified",
        session: data.session,
        user: data.user,
        profile,
        isNewUser,
      });
    } catch (error) {
      request.log.error(error);

      return reply.code(500).send({
        error: error instanceof Error ? error.message : "unable to verify otp",
      });
    }
  });
}
