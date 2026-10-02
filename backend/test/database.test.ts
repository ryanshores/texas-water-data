import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import type { NormalizedReservoir } from "../src/normalize";
import { readDashboard, upsertCurrentConditions } from "../src/database";

describe("dashboard queries", () => {
  beforeEach(async () => {
    await env.DB.prepare("DROP TABLE IF EXISTS observations").run();
    await env.DB.prepare("DROP TABLE IF EXISTS reservoirs").run();
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
    await upsertCurrentConditions(env.DB, [reservoir("2026-09-24", 60)]);
    await upsertCurrentConditions(env.DB, [reservoir("2026-10-01", 65)]);

    const dashboard = await readDashboard(env.DB);

    expect(dashboard.statewidePercentFull).toBe(65);
    expect(dashboard.reservoirs).toHaveLength(1);
    expect(dashboard.reservoirs[0]?.trend.sevenDays).toBe(5);
    expect(dashboard.reservoirs[0]?.trend.storageSevenDays).toBe(50);
  });

  it("does not compare a stale or null observation to a trend window", async () => {
    await upsertCurrentConditions(env.DB, [reservoir("2026-09-10", 45)]);
    await upsertCurrentConditions(env.DB, [reservoir("2026-09-24", null)]);
    await upsertCurrentConditions(env.DB, [reservoir("2026-10-01", 65)]);

    const dashboard = await readDashboard(env.DB);

    expect(dashboard.reservoirs[0]?.trend.sevenDays).toBeNull();
    expect(dashboard.reservoirs[0]?.trend.storageSevenDays).toBeNull();
  });
});

function reservoir(observedAt: string, percentFull: number | null): NormalizedReservoir {
  return {
    id: "travis",
    slug: "travis",
    shortName: "Travis",
    fullName: "Lake Travis",
    observedAt,
    latitude: 30.4,
    longitude: -97.9,
    basin: "Colorado",
    region: "Lower Colorado",
    isWaterSupply: true,
    isFloodControl: false,
    percentFull,
    elevation: null,
    surfaceArea: null,
    reservoirStorage: null,
    conservationStorage: percentFull === null ? null : percentFull * 10,
    conservationCapacity: 1000,
    conservationPoolElevation: 681,
    deadPoolCapacity: null,
  };
}
