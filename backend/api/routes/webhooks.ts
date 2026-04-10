import { FastifyInstance } from "fastify";

import { notifyUsersOfNewAlert } from "../funtions/alertNotifications";
import { Alert, AlertStatus } from "../types/alertTypes";

type SupabaseDbWebhookPayload<T> = {
  type?: string;
  table?: string;
  schema?: string;
  record?: T | null;
  old_record?: T | null;
};

function isAuthorizedWebhook(
  secret: string | undefined,
  headers: Record<string, unknown>,
) {
  if (!secret) {
    return true;
  }

  const rawToken = headers["x-webhook-secret"];
  const token = typeof rawToken === "string" ? rawToken : undefined;

  if (token === secret) {
    return true;
  }

  const rawAuth = headers.authorization;
  const authHeader = typeof rawAuth === "string" ? rawAuth : undefined;
  const bearer = authHeader?.startsWith("Bearer ")
    ? authHeader.slice(7)
    : undefined;

  return bearer === secret;
}

export default async function webhooksRoutes(app: FastifyInstance) {
  app.post<{ Body: SupabaseDbWebhookPayload<Alert> }>(
    "/alerts-status",
    async (request, reply) => {
      //   const webhookSecret = process.env.SUPABASE_WEBHOOK_SECRET;
      //   if (!isAuthorizedWebhook(webhookSecret, request.headers)) {
      //     return reply.code(401).send({ error: "unauthorized webhook" });
      //   }

      console.log("Received webhook with body:", request.body);

      const payload = request.body ?? {};
      const nextAlert = payload.record;
      const prevAlert = payload.old_record;

      if (!nextAlert || typeof nextAlert.id !== "number") {
        return reply.code(200).send({
          received: true,
          triggered: false,
          reason: "invalid payload: missing record.id",
        });
      }

      const becamePublished =
        nextAlert.status === AlertStatus.published &&
        prevAlert?.status !== AlertStatus.published;

      console.log("becamePublished:", becamePublished);

      if (!becamePublished) {
        return reply.code(200).send({
          received: true,
          triggered: false,
          reason: "status transition does not require notification",
        });
      }

      const notificationResult = await notifyUsersOfNewAlert(nextAlert);

      return reply.code(200).send({
        received: true,
        triggered: true,
        alertId: nextAlert.id,
        notification: notificationResult,
      });
    },
  );
}
