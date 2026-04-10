import "dotenv/config";
import Fastify from "fastify";

import authRoutes from "./routes/auth";
import queueRoutes from "./routes/queue";
import alertRoutes from "./routes/alerts";
import webhooksRoutes from "./routes/webhooks";

export function buildApp() {
  const app = Fastify({
    logger: true,
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
  const port = Number(process.env.PORT || 3000);
  const host = process.env.HOST || "0.0.0.0";

  try {
    await app.listen({ port, host });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
}

if (require.main === module) {
  void start();
}
