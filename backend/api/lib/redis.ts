import IORedis, { Redis, RedisOptions } from "ioredis";

let redisClient: Redis | undefined;

function getRedisOptions(): RedisOptions {
  return {
    host: process.env.REDIS_HOST || "127.0.0.1",
    port: Number(process.env.REDIS_PORT || 6379),
    db: Number(process.env.REDIS_DB || 0),
    username: process.env.REDIS_USERNAME,
    password: process.env.REDIS_PASSWORD,
    maxRetriesPerRequest: null,
  };
}

export function getRedisClient() {
  if (!redisClient) {
    const redisUrl = process.env.REDIS_URL;
    if (redisUrl) {
      redisClient = new IORedis(redisUrl, { maxRetriesPerRequest: null });
    } else {
      redisClient = new IORedis(getRedisOptions());
    }
  }

  return redisClient;
}

export async function closeRedisClient() {
  if (redisClient) {
    await redisClient.quit();
    redisClient = undefined;
  }
}
