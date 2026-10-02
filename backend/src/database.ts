import type { NormalizedReservoir } from "./normalize";

interface DashboardRow {
  id: string;
  slug: string;
  short_name: string;
  full_name: string;
  observed_at: string;
  latitude: number;
  longitude: number;
  basin: string | null;
  region: string | null;
  is_water_supply: number;
  is_flood_control: number;
  percent_full: number | null;
  elevation: number | null;
  surface_area: number | null;
  reservoir_storage: number | null;
  conservation_storage: number | null;
  conservation_capacity: number | null;
  conservation_pool_elevation: number | null;
  one_day: number | null;
  seven_days: number | null;
  thirty_days: number | null;
  one_year: number | null;
  storage_seven_days: number | null;
}

interface HistoryRow {
  date: string;
  elevation: number | null;
  surface_area: number | null;
  reservoir_storage: number | null;
  conservation_storage: number | null;
  percent_full: number | null;
  conservation_capacity: number | null;
  dead_pool_capacity: number | null;
}

interface HistoryResponse {
  date: string;
  waterLevel: number | null;
  surfaceArea: number | null;
  reservoirStorage: number | null;
  conservationStorage: number | null;
  percentFull: number | null;
  conservationCapacity: number | null;
  deadPoolCapacity: number | null;
}

export async function upsertCurrentConditions(db: D1Database, reservoirs: NormalizedReservoir[]): Promise<void> {
  const ingestedAt = new Date().toISOString();
  const payload = JSON.stringify(reservoirs);
  await db.batch([
    db.prepare(`
      INSERT INTO reservoirs (
        id, slug, short_name, full_name, latitude, longitude, basin, region,
        is_water_supply, is_flood_control, conservation_pool_elevation, is_active, updated_at
      )
      SELECT
        json_extract(value, '$.id'),
        json_extract(value, '$.slug'),
        json_extract(value, '$.shortName'),
        json_extract(value, '$.fullName'),
        json_extract(value, '$.latitude'),
        json_extract(value, '$.longitude'),
        json_extract(value, '$.basin'),
        json_extract(value, '$.region'),
        json_extract(value, '$.isWaterSupply'),
        json_extract(value, '$.isFloodControl'),
        json_extract(value, '$.conservationPoolElevation'),
        1,
        ?
      FROM json_each(?)
      WHERE true
      ON CONFLICT(id) DO UPDATE SET
        slug = excluded.slug,
        short_name = excluded.short_name,
        full_name = excluded.full_name,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        basin = excluded.basin,
        region = excluded.region,
        is_water_supply = excluded.is_water_supply,
        is_flood_control = excluded.is_flood_control,
        conservation_pool_elevation = excluded.conservation_pool_elevation,
        is_active = 1,
        updated_at = excluded.updated_at
    `).bind(ingestedAt, payload),
    db.prepare(`
      UPDATE reservoirs
      SET is_active = 0
      WHERE id NOT IN (
        SELECT json_extract(value, '$.id')
        FROM json_each(?)
      )
    `).bind(payload),
    db.prepare(`
      INSERT INTO observations (
        reservoir_id, date, percent_full, elevation, surface_area, reservoir_storage,
        conservation_storage, conservation_capacity, dead_pool_capacity, ingested_at
      )
      SELECT
        json_extract(value, '$.id'),
        json_extract(value, '$.observedAt'),
        json_extract(value, '$.percentFull'),
        json_extract(value, '$.elevation'),
        json_extract(value, '$.surfaceArea'),
        json_extract(value, '$.reservoirStorage'),
        json_extract(value, '$.conservationStorage'),
        json_extract(value, '$.conservationCapacity'),
        json_extract(value, '$.deadPoolCapacity'),
        ?
      FROM json_each(?)
      WHERE true
      ON CONFLICT(reservoir_id, date) DO UPDATE SET
        percent_full = excluded.percent_full,
        elevation = excluded.elevation,
        surface_area = excluded.surface_area,
        reservoir_storage = excluded.reservoir_storage,
        conservation_storage = excluded.conservation_storage,
        conservation_capacity = excluded.conservation_capacity,
        dead_pool_capacity = excluded.dead_pool_capacity,
        ingested_at = excluded.ingested_at
    `).bind(ingestedAt, payload),
  ]);
}

export async function readDashboard(db: D1Database): Promise<{
  generatedAt: string;
  sourceUpdatedAt: string | null;
  statewidePercentFull: number | null;
  reservoirs: ReturnType<typeof mapDashboardRow>[];
}> {
  const query = db.prepare(`
    WITH latest AS (
      SELECT reservoir_id, MAX(date) AS date
      FROM observations
      GROUP BY reservoir_id
    ), current AS (
      SELECT r.*, o.date AS observed_at, o.percent_full, o.elevation, o.surface_area,
             o.reservoir_storage, o.conservation_storage, o.conservation_capacity
      FROM reservoirs r
      JOIN latest l ON l.reservoir_id = r.id
      JOIN observations o ON o.reservoir_id = l.reservoir_id AND o.date = l.date
      WHERE r.is_active = 1
    )
    SELECT c.*,
      CASE WHEN p1.conservation_capacity IS NULL OR c.conservation_capacity IS NULL
                OR ABS(p1.conservation_capacity - c.conservation_capacity) > MAX(1, c.conservation_capacity * 0.000001)
           THEN NULL ELSE c.percent_full - p1.percent_full END AS one_day,
      CASE WHEN p7.conservation_capacity IS NULL OR c.conservation_capacity IS NULL
                OR ABS(p7.conservation_capacity - c.conservation_capacity) > MAX(1, c.conservation_capacity * 0.000001)
           THEN NULL ELSE c.percent_full - p7.percent_full END AS seven_days,
      CASE WHEN p30.conservation_capacity IS NULL OR c.conservation_capacity IS NULL
                OR ABS(p30.conservation_capacity - c.conservation_capacity) > MAX(1, c.conservation_capacity * 0.000001)
           THEN NULL ELSE c.percent_full - p30.percent_full END AS thirty_days,
      CASE WHEN p365.conservation_capacity IS NULL OR c.conservation_capacity IS NULL
                OR ABS(p365.conservation_capacity - c.conservation_capacity) > MAX(1, c.conservation_capacity * 0.000001)
           THEN NULL ELSE c.percent_full - p365.percent_full END AS one_year,
      CASE WHEN p7.conservation_capacity IS NULL OR c.conservation_capacity IS NULL
                OR ABS(p7.conservation_capacity - c.conservation_capacity) > MAX(1, c.conservation_capacity * 0.000001)
           THEN NULL ELSE c.conservation_storage - p7.conservation_storage END AS storage_seven_days
    FROM current c
    LEFT JOIN observations p1 ON p1.rowid = (
      SELECT rowid FROM observations
      WHERE reservoir_id = c.id
        AND percent_full IS NOT NULL
        AND observations.date < c.observed_at
        AND ABS(julianday(observations.date) - julianday(c.observed_at, '-1 day')) <= 2
      ORDER BY ABS(julianday(observations.date) - julianday(c.observed_at, '-1 day')), observations.date DESC
      LIMIT 1
    )
    LEFT JOIN observations p7 ON p7.rowid = (
      SELECT rowid FROM observations
      WHERE reservoir_id = c.id
        AND percent_full IS NOT NULL
        AND observations.date < c.observed_at
        AND ABS(julianday(observations.date) - julianday(c.observed_at, '-7 day')) <= 2
      ORDER BY ABS(julianday(observations.date) - julianday(c.observed_at, '-7 day')), observations.date DESC
      LIMIT 1
    )
    LEFT JOIN observations p30 ON p30.rowid = (
      SELECT rowid FROM observations
      WHERE reservoir_id = c.id
        AND percent_full IS NOT NULL
        AND observations.date < c.observed_at
        AND ABS(julianday(observations.date) - julianday(c.observed_at, '-30 day')) <= 2
      ORDER BY ABS(julianday(observations.date) - julianday(c.observed_at, '-30 day')), observations.date DESC
      LIMIT 1
    )
    LEFT JOIN observations p365 ON p365.rowid = (
      SELECT rowid FROM observations
      WHERE reservoir_id = c.id
        AND percent_full IS NOT NULL
        AND observations.date < c.observed_at
        AND ABS(julianday(observations.date) - julianday(c.observed_at, '-365 day')) <= 2
      ORDER BY ABS(julianday(observations.date) - julianday(c.observed_at, '-365 day')), observations.date DESC
      LIMIT 1
    )
    ORDER BY c.short_name COLLATE NOCASE
  `);
  const result = await query.all<DashboardRow>();
  const reservoirs = result.results.map(mapDashboardRow);
  const totals = reservoirs.reduce((value, reservoir) => {
    if (reservoir.conservationStorage === null || reservoir.conservationCapacity === null) {
      return value;
    }
    return {
      storage: value.storage + reservoir.conservationStorage,
      capacity: value.capacity + reservoir.conservationCapacity,
    };
  }, { storage: 0, capacity: 0 });

  return {
    generatedAt: new Date().toISOString(),
    sourceUpdatedAt: reservoirs.map((item) => item.observedAt).sort().at(-1) ?? null,
    statewidePercentFull: totals.capacity > 0 ? (totals.storage / totals.capacity) * 100 : null,
    reservoirs,
  };
}

export async function readHistory(db: D1Database, reservoirID: string, days: number): Promise<HistoryResponse[]> {
  const result = await db.prepare(`
    SELECT date, elevation, surface_area, reservoir_storage, conservation_storage,
           percent_full, conservation_capacity, dead_pool_capacity
    FROM observations
    WHERE reservoir_id = ?
      AND date >= (
        SELECT date(MAX(date), ?)
        FROM observations
        WHERE reservoir_id = ?
      )
    ORDER BY date ASC
  `).bind(reservoirID, `-${days} days`, reservoirID).all<HistoryRow>();

  return result.results.map((row) => ({
    date: row.date,
    waterLevel: row.elevation,
    surfaceArea: row.surface_area,
    reservoirStorage: row.reservoir_storage,
    conservationStorage: row.conservation_storage,
    percentFull: row.percent_full,
    conservationCapacity: row.conservation_capacity,
    deadPoolCapacity: row.dead_pool_capacity,
  }));
}

function mapDashboardRow(row: DashboardRow) {
  return {
    id: row.id,
    slug: row.slug,
    shortName: row.short_name,
    fullName: row.full_name,
    observedAt: row.observed_at,
    latitude: row.latitude,
    longitude: row.longitude,
    basin: row.basin,
    region: row.region,
    isWaterSupply: row.is_water_supply === 1,
    isFloodControl: row.is_flood_control === 1,
    percentFull: row.percent_full,
    elevation: row.elevation,
    surfaceArea: row.surface_area,
    reservoirStorage: row.reservoir_storage,
    conservationStorage: row.conservation_storage,
    conservationCapacity: row.conservation_capacity,
    conservationPoolElevation: row.conservation_pool_elevation,
    trend: {
      oneDay: row.one_day,
      sevenDays: row.seven_days,
      thirtyDays: row.thirty_days,
      oneYear: row.one_year,
      storageSevenDays: row.storage_seven_days,
    },
  };
}
