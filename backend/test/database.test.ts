import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { readDashboard } from "../src/database";

describe("dashboard queries", () => {
  beforeEach(async () => {
    await env.DB.prepare(`
      CREATE TABLE reservoirs (
        id TEXT PRIMARY KEY,
        slug TEXT NOT NULL UNIQUE,
        short_name TEXT NOT NULL,
        full_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        basin TEXT,
        region TEXT,
        is_water_supply INTEGER NOT NULL,
        is_flood_control INTEGER NOT NULL,
        conservation_pool_elevation REAL,
        updated_at TEXT NOT NULL
      )
    `).run();
    await env.DB.prepare(`
      CREATE TABLE observations (
        reservoir_id TEXT NOT NULL,
        date TEXT NOT NULL,
        percent_full REAL,
        elevation REAL,
        surface_area REAL,
        reservoir_storage REAL,
        conservation_storage REAL,
        conservation_capacity REAL,
        dead_pool_capacity REAL,
        ingested_at TEXT NOT NULL,
        PRIMARY KEY (reservoir_id, date)
      )
    `).run();
  });

  it("calculates comparable changes from daily observations", async () => {
    await env.DB.prepare(`
      INSERT INTO reservoirs (
        id, slug, short_name, full_name, latitude, longitude, basin, region,
        is_water_supply, is_flood_control, conservation_pool_elevation, updated_at
      ) VALUES ('travis', 'travis', 'Travis', 'Lake Travis', 30.4, -97.9,
                'Colorado', 'Lower Colorado', 1, 0, 681, '2026-10-01')
    `).run();
    await env.DB.batch([
      env.DB.prepare(`
        INSERT INTO observations (
          reservoir_id, date, percent_full, conservation_storage,
          conservation_capacity, ingested_at
        ) VALUES ('travis', '2026-09-24', 60, 600, 1000, '2026-09-24')
      `),
      env.DB.prepare(`
        INSERT INTO observations (
          reservoir_id, date, percent_full, conservation_storage,
          conservation_capacity, ingested_at
        ) VALUES ('travis', '2026-10-01', 65, 650, 1000, '2026-10-01')
      `),
    ]);

    const dashboard = await readDashboard(env.DB);

    expect(dashboard.statewidePercentFull).toBe(65);
    expect(dashboard.reservoirs).toHaveLength(1);
    expect(dashboard.reservoirs[0]?.trend.sevenDays).toBe(5);
    expect(dashboard.reservoirs[0]?.trend.storageSevenDays).toBe(50);
  });
});
