import { Queue, Worker } from "bullmq";

import { closeRedisClient, getRedisClient } from "../lib/redis";
import { getSupabaseServiceClient } from "../lib/supabase";
import { deleteAlert } from "../funtions/alertOperations";
import { LoggerLike } from "../types/loggerTypes";
import { ALERT_QUEUE_NAME, Alert } from "../types/alertTypes";
import {
  alertModeration_Tier1,
  alertModeration_Tier3,
  alertModeration_Tier2,
} from "../funtions/alertModerations";
import { notifyUsersOfNewAlert } from "../funtions/alertNotifications";

let alertQueue: Queue | undefined;
let alertWorker: Worker | undefined;

function parseAlertJobData(data: unknown): { alert: Alert; tier: number } {
  const raw = data as { alert?: Alert; tier?: number } | undefined;
  const alert = raw?.alert;

  if (!alert || typeof alert !== "object") {
    throw new Error("invalid job payload: missing alert");
  }

  if (typeof alert.id !== "number") {
    throw new Error("invalid job payload: alert.id must be a number");
  }

  const tier = Number(raw?.tier ?? alert.tier ?? 1);
  if (![1, 2, 3, 4].includes(tier)) {
    throw new Error(`invalid job payload: unsupported tier ${tier}`);
  }

  return { alert, tier };
}

export function getAlertQueue() {
  if (!alertQueue) {
    alertQueue = new Queue(ALERT_QUEUE_NAME, {
      connection: getRedisClient(),
    });
  }

  return alertQueue;
}

export function startAlertWorker(logger?: LoggerLike) {
  if (alertWorker) {
    return alertWorker;
  }

  alertWorker = new Worker(
    ALERT_QUEUE_NAME,
    async (job) => {
      const { alert, tier } = parseAlertJobData(job.data);
      const serviceClient = getSupabaseServiceClient();

      try {
        if (tier === 1) {
          await alertModeration_Tier1(alert);
        }

        if (tier === 2) {
          await alertModeration_Tier2(alert);
        }

        if (tier === 3 || tier === 4) {
          await alertModeration_Tier3(alert);
        }

        const { data: finalAlert, error: finalAlertError } = await serviceClient
          .from("alerts")
          .select("*")
          .eq("id", alert.id)
          .single();

        if (finalAlertError) {
          throw new Error(
            `failed to load moderated alert ${alert.id}: ${finalAlertError.message}`,
          );
        }

        const notificationResult =
          tier === 3 || tier === 4
            ? await notifyUsersOfNewAlert(finalAlert)
            : null;

        return {
          processedAt: new Date().toISOString(),
          message: `alert job processed JOB ID: ${job.id} for tier ${tier}. Alert ID: ${alert?.id}`,
          notification: notificationResult,
        };
      } catch (error) {
        try {
          await deleteAlert(alert.id, serviceClient);
        } catch (rollbackError) {
          logger?.error(
            { alertId: alert.id, rollbackError },
            "failed to delete alert after worker error",
          );
        }

        throw error;
      }
    },
    {
      connection: getRedisClient(),
    },
  );

  alertWorker.on("completed", (job, result) => {
    logger?.info({ jobId: job.id, result }, "bullmq alert job completed");
  });

  alertWorker.on("failed", (job, error) => {
    logger?.error(
      { jobId: job?.id, error: error.message },
      "bullmq alert job failed",
    );
  });

  return alertWorker;
}

export async function stopAlertWorker() {
  if (alertWorker) {
    await alertWorker.close();
    alertWorker = undefined;
  }

  if (alertQueue) {
    await alertQueue.close();
    alertQueue = undefined;
  }

  await closeRedisClient();
}
