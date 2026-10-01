# Texas Water

Texas Water is a native iOS project for quickly understanding Texas reservoir
conditions: what is full, what is low, and what is changing fastest.

The project is currently through **Phase 0**. It includes:

- a generated SwiftUI iOS application project;
- a reusable `TexasWaterCore` Swift package;
- typed decoders for TWDB current-condition JSON and historical CSV;
- change calculations that guard against stale data and capacity revisions;
- a live data-proof command that inventories and validates the official feeds;
- deterministic XCTest parser and analytics tests; and
- the product plan and data-source inventory under `docs/`.

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
