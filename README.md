# Texas Water

Texas Water is a native iOS project for quickly understanding Texas reservoir
conditions: what is full, what is low, and what is changing fastest.

The project now has a working **Phase 1 reservoir MVP foundation**. It includes:

- a generated SwiftUI iOS app with Today, reservoir browsing, detail charts,
  favorites, and a map;
- a reusable `TexasWaterCore` Swift package;
- typed decoders for TWDB current-condition JSON and historical CSV;
- change calculations that guard against stale data and capacity revisions;
- an offline dashboard/history cache with direct-TWDB fallback;
- a scheduled Cloudflare Worker and normalized D1 API for compact mobile reads;
- strict Worker-runtime tests and CI for both Swift and TypeScript; and
- a live data-proof command that inventories and validates the official feeds;
- deterministic parser and analytics tests; and
- the product plan, data inventory, and Phase 1 status under `docs/`.

## Open the app

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

Then open `TexasWater.xcodeproj`. A full Xcode installation is required to build
the iOS app. The command-line Swift package can be built and tested separately.

## Test the data layer

```sh
swift test --package-path Packages/TexasWaterCore
```

The tests require XCTest from a full Xcode toolchain. Apple's standalone
Command Line Tools can build the package and proof executable but may not ship
the XCTest module.

## Test the backend

```sh
cd backend
npm ci
npm run check
```

See `backend/README.md` for local D1 setup and the account-owner deployment
steps. The app does not require the backend during development.

## Run the live Phase 0 proof

```sh
swift run --package-path Packages/TexasWaterCore reservoir-data-proof \
  --output phase-0-report.json
```

The command reads only public TWDB endpoints. It fetches the current reservoir
catalog, discovers official history slugs, validates one year of history for
each reservoir, and writes a machine-readable report. Use `--limit 5` for a
quick smoke test.

## Data source

Reservoir data is provided by the Texas Water Development Board through
[Water Data for Texas](https://waterdatafortexas.org/reservoirs/statewide).
Values are best estimates, may be revised, and should always be displayed with
their source timestamp.
