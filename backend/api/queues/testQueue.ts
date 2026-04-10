import { Queue, Worker } from "bullmq";

import { closeRedisClient, getRedisClient } from "../lib/redis";

const TEST_QUEUE_NAME = "test-jobs";

type LoggerLike = {
  info: (obj: unknown, msg?: string) => void;
  error: (obj: unknown, msg?: string) => void;
};

let testQueue: Queue | undefined;
let testWorker: Worker | undefined;

export function getTestQueue() {
  if (!testQueue) {
    testQueue = new Queue(TEST_QUEUE_NAME, {
      connection: getRedisClient(),
    });
  }

  return testQueue;
}

export function startTestWorker(logger?: LoggerLike) {
  if (testWorker) {
    return testWorker;
  }

  testWorker = new Worker(
    TEST_QUEUE_NAME,
    async (job) => {
      const delayMs = Number(job.data?.delayMs || 0);
      if (delayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }

      return {
        processedAt: new Date().toISOString(),
        message: job.data?.message || "test job processed",
      };
    },
    {
      connection: getRedisClient(),
    },
  );

  testWorker.on("completed", (job, result) => {
    logger?.info({ jobId: job.id, result }, "bullmq test job completed");
  });

  testWorker.on("failed", (job, error) => {
    logger?.error(
      { jobId: job?.id, error: error.message },
      "bullmq test job failed",
    );
  });

  return testWorker;
}

export async function stopTestWorker() {
  if (testWorker) {
    await testWorker.close();
    testWorker = undefined;
  }

  if (testQueue) {
    await testQueue.close();
    testQueue = undefined;
  }

  await closeRedisClient();
}
