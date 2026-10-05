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

For an authenticated production deployment, use the interactive deployment
flow. It installs dependencies, runs the checks, pauses for Wrangler account
confirmation, shows remote migration state, asks before applying migrations,
and asks for confirmation immediately before deployment:

```sh
npm run deploy
```

After deployment, verify the public Worker and all JSON routes with:

```sh
npm run health
# or: TEXAS_WATER_API_BASE_URL=https://your-worker.example.com npm run health
```

The deploy flow can remind you to run the scheduled ingestion from the
Cloudflare dashboard. Wrangler does not provide a production scheduled-event
invoke command for this Worker.

The local API exposes:

- `GET /health`
- `GET /v1/dashboard`
- `GET /v1/reservoirs/:id/history?range=30d|1y`
- `GET /v1/drought` — statewide D0-D4 percentages, week-over-week deltas, and
  categorized map areas from the TWDB Drought Monitor.
- `GET /v1/drought/context` — dated soil-moisture and drought-index maps plus
  a current representative-streamflow summary from TWDB.
- `GET /v1/drought/counties` — official Texas county catalog for search.
- `GET /v1/drought/counties/:name` — historical D0-D4 percentages and the
  official boundary for a county.

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

### Historical backfill

The scheduled ingest builds history from the date the Worker is deployed onward.
Run the repeatable backfill utility once to seed the official one-year records
needed for movers and long-range charts:

```sh
cd backend
npm run backfill:history
for file in .backfill/*/chunk-*.sql; do
  npx wrangler d1 execute texas-water --remote --file "$file"
done
```

The utility fetches the live production catalog to preserve the D1 reservoir
identifiers, downloads each official TWDB one-year CSV with bounded retries, and
emits idempotent SQL chunks. It never needs a Cloudflare token in the repository;
Wrangler supplies authentication for the remote D1 commands.

No credentials are stored in this repository. The Worker is intentionally
read-only over HTTP; ingestion only runs through the scheduled handler.
