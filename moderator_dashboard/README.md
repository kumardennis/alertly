# Alertly Moderator Dashboard

This is a React + Vite dashboard for reviewing alerts.

Moderators sign in with phone OTP, then review alerts via the backend moderation APIs.

## Environment

Create `.env` from `.env.example` and set at least:

- `VITE_API_BASE` to your deployed backend origin, for example `https://your-backend.vercel.app`

Optional (already defaulted to current Alertly project values):

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

## Run

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Notes

- The dashboard expects backend endpoints:
  - `POST /api/auth/register`
  - `GET /api/alerts/moderation/queue`
  - `PATCH /api/alerts/review`
- Review and queue endpoints require moderator role on the backend.
