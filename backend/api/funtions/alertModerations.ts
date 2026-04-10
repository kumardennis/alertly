import { Alert } from "../types/alertTypes";
import { getSupabaseServiceClient } from "../lib/supabase";
import { updateAlert } from "./alertOperations";
import { getUser } from "./userOperations";

const serviceClient = getSupabaseServiceClient();

export const alertModeration_Tier1 = async (alert: Alert) => {
  const isProfane = await checkProfanity(alert.title, alert.body);
  const hasSimilarAlerts = checkSameCategoryAndRadius(alert);
  const userReputationOk = await checkUserReputationOk(String(alert.user_id));

  if (isProfane || hasSimilarAlerts || !userReputationOk) {
    await markAsFlagged(String(alert.id));
    await notifyModerators(String(alert.id));

    return;
  }

  await updateAlert(
    Number(alert.id),
    { status: "published", published_at: new Date().toISOString() },
    serviceClient,
  );
};

export const alertModeration_Tier2 = async (alert: Alert) => {
  const isProfane = await checkProfanity(alert.title, alert.body);
  const hasSimilarAlerts = checkSameCategoryAndRadius(alert);
  const userReputationOk = await checkUserReputationOk(String(alert.user_id));

  if (isProfane || hasSimilarAlerts || !userReputationOk) {
    await markAsFlagged(String(alert.id));
    await notifyModerators(String(alert.id));

    return;
  }

  const delayMs = 1000 * 60 * 5; // 5 minutes delay for Tier 2 moderation

  await new Promise((resolve) => setTimeout(resolve, delayMs));

  await updateAlert(Number(alert.id), { status: "published" }, serviceClient);
};

export const alertModeration_Tier3 = async (alert: Alert) => {
  const isProfane = await checkProfanity(alert.title, alert.body);
  const hasSimilarAlerts = checkSameCategoryAndRadius(alert);
  const userReputationOk = await checkUserReputationOk(String(alert.user_id));

  if (isProfane || hasSimilarAlerts || !userReputationOk) {
    await markAsFlagged(String(alert.id));
    await notifyModerators(String(alert.id));
  }
};

const checkProfanity = async (
  title: string | null,
  body: string | null,
): Promise<boolean> => {
  if (!title && !body) {
    return false;
  }
  const response = await fetch("https://api.openai.com/v1/moderations", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      input: `${title}. ${body}`,
    }),
  });

  const data = await response.json();
  const flagged = data.results[0].flagged;

  return flagged;
};

const checkSameCategoryAndRadius = (alert: Alert): boolean => {
  return false; // Placeholder until duplicate/radius detection is implemented.
};

const checkUserReputationOk = async (userId: string): Promise<boolean> => {
  const parsedUserId = Number(userId);
  if (!Number.isFinite(parsedUserId)) {
    return false;
  }

  const userData = await getUser({ id: parsedUserId }, serviceClient);
  const reputationScore = userData?.[0]?.rep_score || 0;

  return reputationScore > 50;
};

const markAsFlagged = async (alertId: string) => {
  await updateAlert(Number(alertId), { flagged: true }, serviceClient);
};

const notifyModerators = async (alertId: string) => {}; // Might not need to notify because they can just open dashboarid
