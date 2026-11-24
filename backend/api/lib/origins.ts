function normalizeOrigin(origin: string) {
  return origin
    .trim()
    .replace(/^['"]|['"]$/g, "")
    .toLowerCase()
    .replace(/\/+$/, "");
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

export function getBrowserAllowedOrigins() {
  const raw =
    process.env.AUTH_BROWSER_ORIGINS?.trim() ||
    process.env.CORS_ORIGINS?.trim() ||
    "";

  return raw
    .split(",")
    .map((origin) => normalizeOrigin(origin))
    .filter(Boolean);
}

export function isAllowedBrowserOrigin(origin: string | undefined) {
  if (!origin) {
    return { isBrowser: false, allowed: true as const };
  }

  const normalized = normalizeOrigin(origin);
  const allowedOrigins = getBrowserAllowedOrigins();

  if (allowedOrigins.length === 0) {
    // No allowlist configured — don't hard-block, but treat as browser.
    return { isBrowser: true, allowed: true as const };
  }

  const allowed = allowedOrigins.some((pattern) =>
    matchesOrigin(normalized, pattern),
  );

  return { isBrowser: true, allowed };
}
