type TurnstileVerifyResponse = {
  success?: boolean;
  "error-codes"?: string[];
};

export function isTurnstileConfigured() {
  return Boolean(process.env.TURNSTILE_SECRET_KEY?.trim());
}

export async function verifyTurnstileToken(params: {
  token: string;
  remoteIp?: string;
}): Promise<{ ok: boolean; error?: string }> {
  const secret = process.env.TURNSTILE_SECRET_KEY?.trim();
  if (!secret) {
    return { ok: true };
  }

  const body = new URLSearchParams();
  body.set("secret", secret);
  body.set("response", params.token);
  if (params.remoteIp) {
    body.set("remoteip", params.remoteIp);
  }

  const response = await fetch(
    "https://challenges.cloudflare.com/turnstile/v0/siteverify",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    },
  );

  if (!response.ok) {
    return { ok: false, error: "Captcha verification failed." };
  }

  const payload = (await response.json()) as TurnstileVerifyResponse;
  if (!payload.success) {
    return {
      ok: false,
      error: "Captcha failed. Please try again.",
    };
  }

  return { ok: true };
}
