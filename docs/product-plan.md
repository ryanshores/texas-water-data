# Texas Water iOS product plan

## Product goal

Make Texas water conditions understandable in seconds on a phone, with special
emphasis on favorite reservoirs, rapid changes, and full or critically low
conditions. Reservoirs are the first release; drought and groundwater follow
after the core experience is reliable.

## Primary experience

### Today

- Statewide percent full with 1-day, 7-day, 30-day, and 1-year changes.
- Compact statewide drought summary below the reservoir hero: D0+ coverage,
  D2+ coverage, current highest drought category, week-over-week movement,
  observation date, and source attribution. A single action opens the Drought
  tab for the map and county history; county selection and the full history
  chart stay out of Today.
- Favorite reservoirs.
- Fastest rising and fastest falling reservoirs.
- Near-full, low, and critically low reservoirs.
- Explicit source timestamp and stale-data state.

### Reservoir detail

- Percent full and trend direction.
- Interactive 30-day, 1-year, and period-of-record charts.
- Conservation storage, capacity, surface area, and water elevation.
- Storage-scale context: conservation capacity, statewide capacity share, and a
  clearly labeled small/medium/large capacity tier.
- Height above or below conservation pool.
- Basin, planning region, municipal area, and reservoir type.
- Official source link, methodology, and provisional-data language.

### Browse and map

- Search by lake name.
- Filter by basin, planning region, municipal area, and distance.
- Sort by fastest rising/falling, fullest/lowest, storage change, or distance.
- Toggle statewide rankings between all reservoirs and major-capacity reservoirs
  so a rapid change at a small lake does not obscure a large water-supply
  reservoir.
- MapKit marker clustering with accessible status labels.

### Basin detail

- Basin summary with weighted percent full, total conservation storage and
  capacity, reservoir count, and the latest source timestamp.
- A basin's biggest reservoirs, fastest movers, low/near-full conditions, and
  a drill-down list of its reservoirs.
- Basin-filtered reservoir markers on the map. Basin boundary polygons remain
  a later enhancement until an official geometry source is contract-tested.

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

- Today dashboard, favorites, movers, full/low rankings. **Merged.**
- Search, basin filtering, detail charts, and map. **Merged.**
- Backend ingestion, normalized API, offline cache, and freshness states.
  **Implemented; production D1 migrations and Worker deployment are complete.
  Historical observations have been backfilled through the current one-year
  window.**
- Small and medium widgets. **Merged and device-validated; follow-up issue
  [#5](https://github.com/ryanshores/texas-water-data/issues/5) tracks reservoir
  deep links and small-family percentage truncation.**
- Accessibility, TestFlight, and source attribution. **Complete for Phase 1.**

### Phase 1.1 — alerts and polish

- Threshold and rapid-change local alerts evaluated on refresh. Remote APNs
  delivery is deferred until distribution work. **Implemented for local
  development.**
- Weekly favorite summary, Lock Screen widgets, and reservoir deep links.
  **Implemented.**
- Privacy, attribution, data-source, API health, and notification-preference
  screens. **Implemented for local development.**

### Phase 1.2 — reservoir scale and basin intelligence

- Calculate reservoir capacity tiers from the active statewide catalog. Show
  both the tier and exact conservation capacity; avoid calling this an
  importance score because capacity does not capture flood-control, safety, or
  local operational importance.
- Show each reservoir's share of statewide conservation capacity and add an
  all-reservoirs/major-reservoirs control to the Today rankings.
- Add basin summaries using capacity-weighted percent full. Exclude a reservoir
  from the weighted calculation unless both conservation storage and capacity
  are available, and always show the included-reservoir count.
- Add basin drill-down screens with major reservoirs, movers, conditions, and
  a basin-filtered map/list.
- Add unit coverage for tier boundaries, paired storage/capacity aggregation,
  and basin rollups. Validate direct-TWDB and backend results match.

**Status: implemented and merged.**

## Current position and recommended sequence

Phase 0, Phase 1, Phase 1.1, and Phase 1.2 are complete for local development.
The production Worker is deployed, the app is configured to use it, historical
observations have been backfilled, and the app has passed the release-readiness
checks. Remote APNs delivery and App Store distribution remain deferred until an
Apple Developer Program account is in scope.

1. Complete Phase 2: drought conditions and county-level context.
2. Revisit APNs delivery and App Store distribution when an Apple Developer
   Program account is available.

### Phase 2 — drought

- County status, statewide D0-D4 summary, week-over-week change, and map.
- The main map combines drought footprints with reservoir markers. The Drought
  and Reservoirs screens each provide an expandable full-screen map scoped to
  their own data.
- Integrate the statewide drought summary into Today without loading the county
  catalog there. ContentView owns one shared DroughtDataStore; Today loads only
  the lightweight overview, while the Drought tab loads the county catalog and
  detail history on demand. Reservoir and drought refreshes remain independent
  so a drought outage does not hide reservoir data.
- Provide loading, stale-data, and error states for the Today card, preserve
  the last successful drought overview, and expose a combined VoiceOver label
  for the key percentages and changes.
- Soil moisture, streamflow, and drought-index layers as progressive additions.

**Status: in progress.** The first slice adds a
read-only `/v1/drought` contract backed by the TWDB Drought Monitor, statewide
D0-D4 percentages with week-over-week deltas, categorized map areas, a SwiftUI
Drought tab, and a refreshable source/error state. County history is available
through `/v1/drought/counties/{county}`. The county-detail slice adds the
official county catalog, searchable selection, six-month D0+/D2+ coverage
history, and exact TWDB county boundary rendering. Soil moisture, streamflow,
and additional drought-index layers remain follow-on work. The Today
summary card and shared overview loading are now implemented on the
`feature/today-drought-summary` branch; county catalog and history loading
remain scoped to the Drought tab.

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
