import { FastifyInstance } from "fastify";
import { getUser } from "../funtions/userOperations";
import {
  ALERT_QUEUE_NAME,
  AlertInsert,
  AlertStatus,
} from "../types/alertTypes";
import {
  createAlert,
  deleteAlert,
  getAlerts,
  updateAlert,
} from "../funtions/alertOperations";
import { getAlertQueue } from "../queues/alertQueue";
import {
  getAuthedSupabaseClient,
  getSupabaseServiceClient,
} from "../lib/supabase";

type AlertBody = {
  radius_m: number | null | undefined;
  title: string;
  message: string;
  userId?: number;
  locationLongitude?: string;
  locationLatitude?: string;
  category?: string;
};

type ReviewBody = {
  alertId: string;
  status: AlertStatus;
  flagged?: boolean;
};

export default async function alertRoutes(app: FastifyInstance) {
  app.post<{ Body: AlertBody }>("/submit", async (request, reply) => {
    const { title, message, userId, category } = request.body ?? {};
    let createdAlertId: number | undefined;

    if (!title || !message) {
      return reply.code(400).send({
        error: "title and message are required",
      });
    }

    if (!Number.isFinite(userId)) {
      return reply.code(400).send({
        error: "userId is required and must be a number",
      });
    }

    try {
      const authHeader = request.headers.authorization;
      const jwt = authHeader?.startsWith("Bearer ")
        ? authHeader.slice(7)
        : undefined;

      if (!jwt) {
        return reply.code(401).send({ error: "authentication required" });
      }

      const authedClient = getAuthedSupabaseClient(jwt);

      // Get user data from supabase
      const userData = await getUser({ id: userId }, authedClient);

      // Check user role
      const role = userData?.[0]?.role?.role;

      // Determine tier of moderation based on user role
      let tier = 1;
      if (role === "verified") {
        tier = 2;
      } else if (role === "municipality") {
        tier = 3;
      }

      if (category === "emergency") {
        tier = 4; // Emergency alerts have post-publish moderation and are published immediately
      }

      // add to supabase table with status "pending"
      const newAlert: AlertInsert = {
        title,
        body: message,
        status:
          tier === 3 || tier === 4
            ? AlertStatus.published
            : AlertStatus.pending,
        location: `POINT(${request.body.locationLongitude} ${request.body.locationLatitude})`,
        tier,
        user_id: userId,
        category,
        published_at: tier === 3 || tier === 4 ? "now()" : null,
        radius_m: request.body.radius_m, // default radius of 1km
      };
      const data = await createAlert(newAlert, authedClient);
      createdAlertId = data.id;

      if (!data) {
        return reply.code(500).send({
          error: "unable to create alert",
        });
      }

      // add to bullmq queue for processing by workers
      const job = await getAlertQueue().add("process-alert", {
        alert: data,
      });

      return reply.code(201).send({
        message: "alert submitted successfully",
        alert: {
          title,
          message,
        },
        queue: ALERT_QUEUE_NAME,
        jobId: job.id,
      });
    } catch (error) {
      if (createdAlertId != null) {
        try {
          await deleteAlert(createdAlertId, getSupabaseServiceClient());
        } catch (rollbackError) {
          request.log.error(
            { createdAlertId, rollbackError },
            "failed to roll back alert after submit error",
          );
        }
      }

      request.log.error(error);
      return reply.code(500).send({
        error: "unable to submit alert",
      });
    }
  });

  app.patch<{ Body: ReviewBody }>("/review", async (request, reply) => {
    const { alertId, status, flagged } = request.body ?? {};

    if (!alertId) {
      return reply.code(400).send({
        error: "alertId is required",
      });
    }

    try {
      // Get alert data from supabase
      const alertData = await getAlerts({ id: Number(alertId) });

      // Update status in supabase
      if (!alertData?.[0]) {
        return reply.code(404).send({
          error: "alert not found",
        });
      }

      const data = await updateAlert(Number(alertId), { status, flagged });

      return reply.code(201).send({
        message: "alert reviewed successfully",
        alert: {
          alertId,
          data,
        },
      });
    } catch (error) {
      request.log.error(error);
      return reply.code(500).send({
        error: "unable to review alert",
      });
    }
  });
}
