# Texas Water iOS product plan

## Product goal

Make Texas water conditions understandable in seconds on a phone, with special
emphasis on favorite reservoirs, rapid changes, and full or critically low
conditions. Reservoirs are the first release; drought and groundwater follow
after the core experience is reliable.

## Primary experience

### Today

- Statewide percent full with 1-day, 7-day, 30-day, and 1-year changes.
- Favorite reservoirs.
- Fastest rising and fastest falling reservoirs.
- Near-full, low, and critically low reservoirs.
- Explicit source timestamp and stale-data state.

### Reservoir detail

- Percent full and trend direction.
- Interactive 30-day, 1-year, and period-of-record charts.
- Conservation storage, capacity, surface area, and water elevation.
- Height above or below conservation pool.
- Basin, planning region, municipal area, and reservoir type.
- Official source link, methodology, and provisional-data language.

### Browse and map

- Search by lake name.
- Filter by basin, planning region, municipal area, and distance.
- Sort by fastest rising/falling, fullest/lowest, storage change, or distance.
- MapKit marker clustering with accessible status labels.

### Widgets and alerts

- Small favorite-reservoir widget.
- Medium multi-reservoir widget.
- Statewide and movers widget.
- User-defined threshold-crossing and rapid-change alerts.

## Change semantics

Percentage-point change is the primary comparable metric. Raw water-level and
acre-foot changes are secondary because reservoir size and shape differ.

- 1-day, 7-day, 30-day, and 1-year changes use the nearest valid daily record.
- A comparison is invalid when capacity changed between endpoints.
- Stale and missing data never become zero.
- Default bands: near full >=95%, low <25%, critically low <10%.
- Default rapid-change threshold: absolute 7-day change >=2 percentage points.
- Values above conservation pool are described separately from percent full.

## Architecture

The SwiftUI app uses a thin backend rather than making every phone download all
historical CSV files. The backend periodically ingests TWDB data, stores daily
observations, computes changes, and later sends APNs alerts.

```text
TWDB JSON / CSV / GeoJSON
            |
     Scheduled ingestion
            |
   Normalized observations
      | current values
      | daily history
      | derived changes
      | alert state
            |
       Read-only API
      /       |       \
   iOS app  Widgets   APNs
```

Client technologies: SwiftUI, Swift Concurrency, URLSession, Swift Charts,
MapKit, SwiftData, WidgetKit, App Intents, and BackgroundTasks.

## Delivery phases

### Phase 0 — data proof (complete)

- Inventory official endpoints and semantics.
- Decode current JSON and commented historical CSV.
- Validate a one-year backfill across discovered reservoir slugs.
- Implement guarded change calculations.
- Document nulls, freshness, revisions, and identifier risks.
- Add deterministic unit tests and a live proof report.

### Phase 1 — reservoir MVP

- Today dashboard, favorites, movers, full/low rankings. **Implemented.**
- Search, filtering, detail charts, and map. **Implemented.**
- Backend ingestion, normalized API, offline cache, and freshness states.
  **Implemented locally; production deployment and history backfill remain.**
- Small and medium widgets. **Implemented; App Group provisioning remains.**
- Accessibility, TestFlight, and source attribution.

### Phase 1.1 — alerts and polish

- Threshold and rapid-change APNs alerts.
- Weekly favorite summary, Lock Screen widgets, and deep links.
- App Store privacy, support, attribution, and data-source screens.

### Phase 2 — drought

- County status, statewide D0-D4 summary, week-over-week change, and map.
- Soil moisture, streamflow, and drought-index layers as progressive additions.

### Phase 3 — groundwater and weather context

- Favorite and nearby monitoring wells.
- Aquifer/county filters and correctly oriented water-table trends.
- Reservoir rainfall/evaporation and optional TexMesonet context.

## Release gates

- Upstream contract tests pass against saved fixtures and live smoke checks.
- Parsers cover nulls, missing dates, flood-only reservoirs, and revisions.
- Last successful data remains available during an upstream outage.
- Every value has an observation timestamp and source attribution.
- Dynamic Type, VoiceOver, high contrast, and non-color status cues pass QA.
- TWDB attribution, polling, and redistribution expectations are confirmed
  before public App Store distribution.
