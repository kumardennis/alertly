import { FastifyInstance } from "fastify";

import { hasRedisConfig } from "../lib/redis";
import { getTestQueue } from "../queues/testQueue";

type EnqueueBody = {
  message?: string;
  delayMs?: number;
};

export default async function queueRoutes(app: FastifyInstance) {
  app.post<{ Body: EnqueueBody }>("/test", async (request, reply) => {
    if (!hasRedisConfig()) {
      return reply.code(503).send({
        error: "queue unavailable: Redis is not configured",
      });
    }

    try {
      const { message, delayMs = 0 } = request.body ?? {};
      const queue = getTestQueue();

      const job = await queue.add("demo", {
        message: message || "hello from bullmq",
        delayMs,
      });

      return reply.code(202).send({
        message: "job queued",
        queue: "test-jobs",
        jobId: job.id,
      });
    } catch (error) {
      request.log.error(error);
      return reply.code(503).send({
        error: "queue unavailable",
      });
    }
  });
}
