import "dotenv/config";

import { startAlertWorker, stopAlertWorker } from "./queues/alertQueue";
import { startTestWorker, stopTestWorker } from "./queues/testQueue";

const logger = {
  info: (obj: unknown, msg?: string) =>
    console.log(msg ?? obj, typeof obj === "object" ? obj : ""),
  error: (obj: unknown, msg?: string) =>
    console.error(msg ?? obj, typeof obj === "object" ? obj : ""),
};

async function shutdown() {
  logger.info({}, "Worker shutting down...");
  await stopAlertWorker();
  await stopTestWorker();
  process.exit(0);
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

const shouldStartTestWorker = process.env.ENABLE_TEST_WORKER === "true";

startAlertWorker(logger);
logger.info({}, "Alert worker started");

if (shouldStartTestWorker) {
  startTestWorker(logger);
  logger.info({}, "Test worker started");
}
