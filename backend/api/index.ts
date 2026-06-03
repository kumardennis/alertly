import "dotenv/config";
import Fastify from "fastify";
import cors from "@fastify/cors";

import { hasRedisConfig } from "./lib/redis";
import { startAlertWorker, stopAlertWorker } from "./queues/alertQueue";
import { startTestWorker, stopTestWorker } from "./queues/testQueue";
import authRoutes from "./routes/auth";
import queueRoutes from "./routes/queue";
import alertRoutes from "./routes/alerts";
import webhooksRoutes from "./routes/webhooks";

function normalizeOrigin(origin: string) {
  return origin.trim().toLowerCase().replace(/\/+$/, "");
}

function matchesOrigin(origin: string, allowedPattern: string) {
  if (!allowedPattern.includes("*")) {
    return origin === allowedPattern;
  }

  const escapedPattern = allowedPattern
    .replace(/[.+?^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*");

  return new RegExp(`^${escapedPattern}$`).test(origin);
}

export function buildApp() {
  const app = Fastify({
    logger: true,
  });

  const corsOrigins = process.env.CORS_ORIGINS?.split(",")
    .map((origin) => normalizeOrigin(origin))
    .filter(Boolean);

  void app.register(cors, {
    origin(origin, callback) {
      if (!origin) {
        callback(null, true);
        return;
      }

      if (!corsOrigins || corsOrigins.length === 0) {
        callback(null, true);
        return;
      }

      const normalizedRequestOrigin = normalizeOrigin(origin);
      const isAllowed = corsOrigins.some((allowedOrigin) =>
        matchesOrigin(normalizedRequestOrigin, allowedOrigin),
      );

      callback(null, isAllowed);
    },
    credentials: true,
  });

  app.get("/health", async () => ({ status: "ok" }));
  app.register(authRoutes, { prefix: "/api/auth" });
  app.register(queueRoutes, { prefix: "/api/queue" });
  app.register(alertRoutes, { prefix: "/api/alerts" });
  app.register(webhooksRoutes, { prefix: "/api/webhooks" });

  return app;
}

export async function start() {
  const app = buildApp();
  const redisConfigured = hasRedisConfig();
  const port = Number(process.env.PORT || 3000);
  const host = process.env.HOST || "0.0.0.0";

  try {
    app.addHook("onClose", async () => {
      await stopAlertWorker();
      await stopTestWorker();
    });

    if (redisConfigured) {
      startAlertWorker(app.log);
      if (process.env.ENABLE_TEST_WORKER === "true") {
        startTestWorker(app.log);
      }
    } else {
      app.log.warn("Redis not configured — queue workers disabled.");
    }

    await app.listen({ port, host });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
}

if (require.main === module) {
  void start();
}
