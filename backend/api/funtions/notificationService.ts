import { messaging } from "../lib/firebase";

type NotificationPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

type SendToTokenInput = {
  token: string;
  notification: NotificationPayload;
};

type SendToManyInput = {
  tokens: string[];
  notification: NotificationPayload;
};

type SendToTopicInput = {
  topic: string;
  notification: NotificationPayload;
};

function toMessage(notification: NotificationPayload) {
  return {
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: notification.data,
  };
}

export async function sendNotificationToToken(input: SendToTokenInput) {
  const { token, notification } = input;

  if (!token) {
    throw new Error("token is required");
  }

  return messaging.send({
    token,
    ...toMessage(notification),
  });
}

export async function sendNotificationToMany(input: SendToManyInput) {
  const { tokens, notification } = input;

  if (!tokens.length) {
    throw new Error("at least one token is required");
  }

  return messaging.sendEachForMulticast({
    tokens,
    ...toMessage(notification),
  });
}

export async function sendNotificationToTopic(input: SendToTopicInput) {
  const { topic, notification } = input;

  if (!topic) {
    throw new Error("topic is required");
  }

  return messaging.send({
    topic,
    ...toMessage(notification),
  });
}