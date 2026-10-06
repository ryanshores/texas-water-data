import { describe, expect, it } from "vitest";
import { fetchGroundwaterHistory, fetchGroundwaterWells } from "../src/groundwater";

describe("groundwater source normalization", () => {
  it("joins current readings to well metadata", async () => {
    const fetcher: typeof fetch = async (input) => String(input).endsWith("wells.geojson")
      ? Response.json({ features: [{ geometry: { coordinates: [-97.7, 30.3] }, properties: { well_number: "1234567", county: "Travis", aquifer: "Trinity", aquifer_type: "Confined", status: "Active" } }] })
      : Response.json({ values: [{ state_well_number: "1234567", date: "2026-10-05", "daily_high_water_level(ft below land surface)": 123.4 }] });
    await expect(fetchGroundwaterWells(fetcher)).resolves.toEqual([{ id: "1234567", county: "Travis", aquifer: "Trinity", aquiferType: "Confined", status: "Active", latitude: 30.3, longitude: -97.7, observedAt: "2026-10-05", depthBelowLandSurface: 123.4 }]);
  });
  it("retains valid dated water-level observations", async () => {
    const fetcher: typeof fetch = async () => Response.json({ values: [{ datetime: "2026-10-05 08:00:00", "water_level(ft below land surface)": 123.4 }, { datetime: "2026-10-05 09:00:00", "water_level(ft below land surface)": 124.6 }, { datetime: "bad", "water_level(ft below land surface)": null }] });
    await expect(fetchGroundwaterHistory("1234567", fetcher)).resolves.toEqual([{ date: "2026-10-05", depthBelowLandSurface: 124 }]);
  });
});
