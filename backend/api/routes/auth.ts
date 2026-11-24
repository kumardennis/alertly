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

const OTP_COOLDOWN_SECONDS = 60;
const memoryOtpCooldowns = new Map<string, number>();

function normalizePhone(phone: string) {
  return phone.trim().replace(/[^\d+]/g, "");
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

export default async function authRoutes(app: FastifyInstance) {
  app.post<{ Body: RegisterBody }>("/register", async (request, reply) => {
    const { phone: rawPhone, channel = "sms" } = request.body ?? {};

    if (!rawPhone) {
      return reply.code(400).send({
        error: "phone is required",
      });
    }

    const phone = normalizePhone(rawPhone);
    if (!phone) {
      return reply.code(400).send({
        error: "phone is required",
      });
    }

    try {
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
        phone,
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
