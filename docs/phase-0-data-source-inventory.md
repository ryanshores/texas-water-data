# Phase 0 data-source inventory

Validated on 2026-10-01 against the public Water Data for Texas service.

## Completed validation

The final throttled proof run completed at 2026-10-01T21:50:49Z:

- 122 current reservoir records decoded.
- 120 records supplied a percent-full value; Addicks and Barker are
  flood-control-only records with null conservation metrics.
- 122 official history slugs discovered.
- 122 of 122 one-year history files downloaded and decoded successfully.
- No successful history was stale by the three-day Phase 0 threshold.
- History files contained 252 to 366 daily observations.
- 118 seven-day changes were usable.
- Addicks and Barker were excluded for missing percent full.
- Elephant Butte and Lake O' the Pines were excluded because conservation
  capacity changed across the comparison window.

The generated `phase-0-report.json` is intentionally ignored by Git because it
is a timestamped operational artifact. Re-run the proof to produce a current
report rather than treating a checked-in snapshot as live data.

## Reservoir sources

| Purpose | Endpoint | Format | Observed behavior |
| --- | --- | --- | --- |
| Current statewide catalog | `/reservoirs/recent-conditions.json` | JSON object keyed by condensed name | Includes names, tags, coordinates, timestamp, storage, elevation, capacity, percent full, and nullable fields. |
| Current map catalog | `/reservoirs/statewide/recent-conditions.geojson` | GeoJSON | Same core values in features suitable for map ingestion. |
| Current flat export | `/reservoirs/recent-conditions.csv` | CSV | Useful for manual review; coordinate and tags fields are serialized Python-like structures. JSON is preferred. |
| Statewide history | `/reservoirs/statewide-1year.csv` | Commented CSV | Daily averaged aggregate observations. Period-of-record and 30-day variants also exist. |
| Reservoir history | `/reservoirs/individual/{slug}-1year.csv` | Commented CSV | Daily averaged water level, surface area, storage, percent full, capacity, and dead pool capacity. |
| Reservoir page | `/reservoirs/individual/{slug}` | HTML | Contains metadata, source/provider notes, official downloads, and provisional instantaneous levels. |
| Statewide page | `/reservoirs/statewide` | HTML | Currently the only discovered public catalog mapping display names to history URL slugs. |

The JSON catalog does **not** include the individual-page slug. Phase 0 tooling
discovers slugs from official links in the statewide HTML page and validates
them. Production ingestion should persist this mapping and alert on additions,
removals, or renames rather than discovering it in the iOS client.

## Historical CSV schema

```text
date,water_level,surface_area,reservoir_storage,conservation_storage,
percent_full,conservation_capacity,dead_pool_capacity
```

Files begin with `#` comments containing the disclaimer, generation time,
methodology URL, units, footnotes, rating curves, conservation pool elevation,
dead pool elevation, and vertical datum. The decoder deliberately ignores
comment lines but validates the complete tabular schema.

## Semantics and quality rules

- Daily reservoir history is estimated daily-average data.
- Recent instantaneous water levels are provisional and are a separate concept.
- Percent full is conservation storage divided by conservation capacity.
- Conservation storage is capped at conservation capacity, so flood-pool water
  must be communicated through elevation above conservation pool instead.
- Flood-control-only reservoirs can have water elevation while percent full,
  storage, area, and capacity are null.
- Capacity and rating curves can change; change calculations must not bridge a
  capacity revision without explicit normalization.
- Today's values can be revised as provider data arrives.
- Missing values remain null; they are never interpreted as empty or zero.
- Store both upstream observation date and ingestion time.

## Other official domains

### Drought

The drought application exposes JSON endpoints used by its own dashboard,
including drought monitor geometry/data, soil moisture, streamflow percentiles,
Keetch-Byram drought index, Quick Drought Response Index, and related map dates.
These endpoints need their own contract proof before Phase 2.

### Groundwater

Individual histories are available at `/groundwater/well/{id}.json` and CSV.
The JSON includes datetime, source, status, timezone, water level in feet below
land surface, and optional temperature/battery values. TWDB also publishes an
ArcGIS Feature Service for statewide well metadata and locations.

Groundwater cannot reuse reservoir percentage semantics: a decreasing depth
below land surface usually means the water table rose.

## Operational recommendations

- Poll current conditions periodically and ingest only changed observation dates.
- Use conditional requests if TWDB later exposes ETag or Last-Modified headers.
- Limit parallel history requests. A live Phase 0 run using batches of six
  succeeded initially, then produced widespread timeouts and HTTP 502 responses.
  The proof command therefore uses batches of two, a delay between batches, and
  bounded exponential retry for transient failures.
- Cache and serve normalized data from the project backend.
- Run daily schema/record-count/freshness checks and alert on drift.
- Retain raw source payload hashes for auditability without duplicating all data.
- Contact TWDB before public launch to confirm attribution, polling frequency,
  and redistribution expectations. No public rate-limit documentation was found.

## Official references

- https://waterdatafortexas.org/reservoirs/statewide
- https://waterdatafortexas.org/reservoirs/download
- https://waterdatafortexas.org/reservoirs/methodology
- https://waterdatafortexas.org/drought
- https://waterdatafortexas.org/groundwater
- https://services.twdb.texas.gov/arcgis/rest/services/Public/TWDB_Groundwater_database/FeatureServer/0
