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
import { hasRedisConfig } from "../lib/redis";
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

type ModerationQueueQuery = {
  status?: AlertStatus;
  flagged?: string;
  limit?: string;
};

const MODERATOR_ROLES = new Set(["moderator", "admin", "municipality"]);

function parseBool(value: string | undefined): boolean | undefined {
  if (value == null) return undefined;
  if (value === "true") return true;
  if (value === "false") return false;
  return undefined;
}

async function requireModerator(
  authorizationHeader: string | undefined,
): Promise<{ authId: string; userId: number }> {
  const jwt = authorizationHeader?.startsWith("Bearer ")
    ? authorizationHeader.slice(7)
    : undefined;

  if (!jwt) {
    throw new Error("UNAUTHORIZED");
  }

  const authedClient = getAuthedSupabaseClient(jwt);
  const {
    data: { user: authUser },
    error: authError,
  } = await authedClient.auth.getUser();

  if (authError || !authUser?.id) {
    throw new Error("UNAUTHORIZED");
  }

  const users = await getUser({ auth_id: authUser.id }, authedClient);
  const appUser = users?.[0] as
    | {
        id: number;
        role?: { role?: string | null } | null;
      }
    | undefined;

  const roleName = appUser?.role?.role?.toLowerCase().trim();
  if (!appUser?.id || !roleName || !MODERATOR_ROLES.has(roleName)) {
    throw new Error("FORBIDDEN");
  }

  return { authId: authUser.id, userId: appUser.id };
}

export default async function alertRoutes(app: FastifyInstance) {
  app.post<{ Body: AlertBody }>("/submit", async (request, reply) => {
    const { title, message, userId, category } = request.body ?? {};
    let createdAlertId: number | undefined;

    if (!hasRedisConfig()) {
      return reply.code(503).send({
        error: "alerts are temporarily unavailable: Redis is not configured",
      });
    }

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

  app.get<{ Querystring: ModerationQueueQuery }>(
    "/moderation/queue",
    async (request, reply) => {
      try {
        await requireModerator(request.headers.authorization);

        const status = request.query.status ?? AlertStatus.pending;
        const flagged = parseBool(request.query.flagged);
        const parsedLimit = Number(request.query.limit ?? "50");
        const limit = Number.isFinite(parsedLimit)
          ? Math.max(1, Math.min(parsedLimit, 200))
          : 50;

        const filters = {
          status,
          ...(flagged !== undefined ? { flagged } : {}),
        };

        const alerts = await getAlerts(filters, getSupabaseServiceClient());

        return reply.code(200).send({
          count: Math.min(alerts.length, limit),
          alerts: alerts.slice(0, limit),
        });
      } catch (error) {
        if (error instanceof Error && error.message === "UNAUTHORIZED") {
          return reply.code(401).send({ error: "authentication required" });
        }
        if (error instanceof Error && error.message === "FORBIDDEN") {
          return reply.code(403).send({ error: "moderator access required" });
        }

        request.log.error(error);
        return reply.code(500).send({
          error: "unable to fetch moderation queue",
        });
      }
    },
  );

  app.patch<{ Body: ReviewBody }>("/review", async (request, reply) => {
    const { alertId, status, flagged } = request.body ?? {};

    if (!alertId) {
      return reply.code(400).send({
        error: "alertId is required",
      });
    }

    if (!status) {
      return reply.code(400).send({
        error: "status is required",
      });
    }

    const validStatuses = new Set(Object.values(AlertStatus));
    if (!validStatuses.has(status)) {
      return reply.code(400).send({
        error: "invalid status",
      });
    }

    try {
      await requireModerator(request.headers.authorization);

      // Get alert data from supabase
      const serviceClient = getSupabaseServiceClient();
      const alertData = await getAlerts({ id: Number(alertId) }, serviceClient);

      // Update status in supabase
      if (!alertData?.[0]) {
        return reply.code(404).send({
          error: "alert not found",
        });
      }

      const data = await updateAlert(
        Number(alertId),
        { status, flagged },
        serviceClient,
      );

      return reply.code(201).send({
        message: "alert reviewed successfully",
        alert: {
          alertId,
          data,
        },
      });
    } catch (error) {
      if (error instanceof Error && error.message === "UNAUTHORIZED") {
        return reply.code(401).send({ error: "authentication required" });
      }
      if (error instanceof Error && error.message === "FORBIDDEN") {
        return reply.code(403).send({ error: "moderator access required" });
      }

      request.log.error(error);
      return reply.code(500).send({
        error: "unable to review alert",
      });
    }
  });
}
