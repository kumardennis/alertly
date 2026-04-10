import { Alert } from "../types/alertTypes";
import { getSupabaseServiceClient } from "../lib/supabase";
import { sendNotificationToMany } from "./notificationService";

type NotifyUsersResult = {
  skipped: boolean;
  reason?: string;
  recipients: number;
  notificationsSent: number;
};

export const notifyUsersOfNewAlert = async (
  alert: Alert,
): Promise<NotifyUsersResult> => {
  const db = getSupabaseServiceClient();

  // Keep notifications idempotent per alert in case jobs are retried.
  //   const { count: existingDeliveries, error: existingError } = await db
  //     .from("users_received_alerts")
  //     .select("id", { head: true, count: "exact" })
  //     .eq("alert_id", alert.id);

  //   console.log(`Existing deliveries for alert ${alert.id}:`, existingDeliveries);

  //   if (existingError) {
  //     throw new Error(
  //       `unable to check delivery records: ${existingError.message}`,
  //     );
  //   }

  //   if ((existingDeliveries ?? 0) > 0) {
  //     return {
  //       skipped: true,
  //       reason: "alert notifications already dispatched",
  //       recipients: 0,
  //       notificationsSent: 0,
  //     };
  //   }

  const { data: eligibleRecipients, error: eligibleRecipientsError } =
    await db.rpc("get_alert_recipient_user_ids", {
      p_alert_id: alert.id,
    });

  console.log(
    "Eligible recipients for alert",
    alert.id,
    ":",
    eligibleRecipients,
  );

  if (eligibleRecipientsError) {
    throw new Error(
      `unable to fetch eligible recipients: ${eligibleRecipientsError.message}`,
    );
  }

  const eligibleUserIds = (eligibleRecipients ?? [3, 4])
    .map((item) => item.user_id)
    .filter((userId): userId is number => typeof userId === "number");

  if (!eligibleUserIds.length) {
    return {
      skipped: true,
      reason: "no recipients matched location filters",
      recipients: 0,
      notificationsSent: 0,
    };
  }

  const { data: devices, error: devicesError } = await db
    .from("users_devices")
    .select("user_id, fcm_token")
    .not("user_id", "is", null)
    .in("user_id", eligibleUserIds)
    .neq("user_id", alert.user_id ?? -1);

  if (devicesError) {
    throw new Error(`unable to fetch device tokens: ${devicesError.message}`);
  }

  const recipients = new Set<number>();
  const tokens = new Set<string>();

  for (const device of devices ?? []) {
    if (typeof device.user_id === "number") {
      recipients.add(device.user_id);
    }

    if (typeof device.fcm_token === "string" && device.fcm_token.length > 0) {
      tokens.add(device.fcm_token);
    }
  }

  if (!tokens.size || !recipients.size) {
    return {
      skipped: true,
      reason: "no eligible recipients",
      recipients: 0,
      notificationsSent: 0,
    };
  }

  const title = "New neighborhood alert!";
  const body = alert.title?.trim() || "A new alert was posted nearby.";

  const fcmResponse = await sendNotificationToMany({
    tokens: [...tokens],
    notification: {
      title,
      body,
      data: {
        alertId: String(alert.id),
        category: alert.category ?? "general",
        status: alert.status ?? "published",
      },
    },
  });

  const deliveryRows = [...recipients].map((receiverId) => ({
    alert_id: alert.id,
    receiver_id: receiverId,
  }));

  const { error: deliveriesError } = await db
    .from("users_received_alerts")
    .insert([
      ...deliveryRows,
      { alert_id: alert.id, receiver_id: alert.user_id },
    ]); // Insert a row with currentuser as well as receiver_id

  if (deliveriesError) {
    throw new Error(
      `unable to persist delivery rows: ${deliveriesError.message}`,
    );
  }

  return {
    skipped: false,
    recipients: recipients.size,
    notificationsSent: fcmResponse.successCount,
  };
};
