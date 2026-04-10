import { FastifyInstance } from "fastify";

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

export default async function authRoutes(app: FastifyInstance) {
  app.post<{ Body: RegisterBody }>("/register", async (request, reply) => {
    const { phone, channel = "sms" } = request.body ?? {};

    if (!phone) {
      return reply.code(400).send({
        error: "phone is required",
      });
    }

    try {
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
