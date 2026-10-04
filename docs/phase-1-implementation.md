# Phase 1 implementation

## What is implemented

The native app now provides the main reservoir MVP:

- a Today dashboard with statewide storage, favorites, fastest movers, low
  reservoirs, and near-full reservoirs;
- searchable reservoir browsing with basin filters and five sort modes;
- reservoir detail pages with current measurements, source attribution, and
  30-day or one-year Swift Charts history;
- a statewide MapKit view with status markers and detail sheets;
- small and medium WidgetKit layouts: a favorite-or-priority reservoir summary
  and a multi-reservoir overview, with direct refresh and saved-data fallback;
- persistent favorites, disk-cached dashboard/history data, offline startup,
  pull-to-refresh, freshness labeling, and direct-TWDB fallback;
- accessible text labels that do not rely on status color alone.

The backend foundation is also implemented:

- a scheduled Cloudflare Worker that validates and ingests the TWDB
  current-conditions feed every two hours;
- a normalized D1 schema for reservoirs, observations, and ingestion runs;
- official statewide-page history-slug mapping, kept with the normalized
  reservoir catalog rather than inferred from a display name;
- guarded 1-day, 7-day, 30-day, and 1-year change queries that suppress changes
  across capacity revisions, stale observations, and missing percentage values;
- dashboard and history endpoints with bounded upstream reads, caching headers,
  structured logs, safe errors, and atomic catalog/observation ingestion;
- Worker-runtime normalization and D1 query tests plus a deploy dry-run.

The iOS app works without the backend by reading the official TWDB JSON and CSV
feeds directly. When an API URL is configured, it prefers the compact backend
response and falls back automatically if the service is empty or unavailable.

## Remaining Phase 1 release work

- The production `texas-water` D1 migrations have been applied and the Worker is
  deployed at `https://texas-water-api.ryan-shores.workers.dev`. Verify `/health`
  and `/v1/dashboard` after future deployments.
- Historical observations have been backfilled through the current one-year
  window. The production history endpoint now returns 366 daily observations
  for populated reservoirs, so movers and long-range charts are available from
  the start.
- The `group.com.ryanshores.TexasWater` App Group is configured and signed-device
  validation is complete.
- Device-level Dynamic Type, VoiceOver, high-contrast, map-density, and
  degraded-network QA is complete.
- App Store/TestFlight metadata, privacy details, source attribution, and the
  first internal build checks are complete. Widget deep linking and small-family
  percentage formatting remain tracked in issue #5.

## Verification commands

```sh
swift build --package-path Packages/TexasWaterCore --product reservoir-data-proof
cd backend
npm ci
npm run check
npx wrangler d1 migrations apply texas-water --local
npx wrangler deploy --dry-run
```

A full Xcode installation is required to compile the iOS target and run XCTest.
Apple's standalone Command Line Tools can parse the SwiftUI sources and build
the platform-neutral core package, but they do not include the iOS SDK or
XCTest module used by this project.
