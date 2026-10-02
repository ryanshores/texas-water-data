# Texas Water API

This Cloudflare Worker is the Phase 1 read API and scheduled reservoir ingester.
It validates the official TWDB current-conditions feed, stores normalized daily
observations in D1, and serves compact dashboard and history responses to the
iOS app.

## Local development

```sh
npm ci
npm run check
npx wrangler d1 migrations apply texas-water --local
npm run dev
```

The local API exposes:

- `GET /health`
- `GET /v1/dashboard`
- `GET /v1/reservoirs/:id/history?range=30d|1y`

Use Wrangler's scheduled-event control while `npm run dev` is running to seed
current observations. The app automatically falls back to the public TWDB feeds
when this API is not configured, has not been seeded, or has no history yet.

## Cloudflare setup

Remote setup intentionally remains an account-owner operation:

1. Run `npx wrangler d1 create texas-water` and add the returned `database_id`
   to `wrangler.jsonc`.
2. Run `npx wrangler d1 migrations apply texas-water --remote`.
3. Run `npx wrangler deploy`.
4. Trigger the scheduled handler once, then verify `/health` and
   `/v1/dashboard`.
5. Put the HTTPS Worker URL in `TEXAS_WATER_API_BASE_URL` in `project.yml` and
   regenerate the Xcode project.

No credentials are stored in this repository. The Worker is intentionally
read-only over HTTP; ingestion only runs through the scheduled handler.
