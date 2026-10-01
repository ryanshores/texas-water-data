import { describe, expect, it } from "vitest";
import { normalizeSnapshot, slugify } from "../src/normalize";

describe("reservoir normalization", () => {
  it("normalizes a TWDB reservoir", () => {
    const reservoir = normalizeSnapshot("Travis", {
      condensed_name: "Travis",
      short_name: "Travis",
      full_name: "Lake Travis",
      timestamp: "2026-10-01",
      gauge_location: { coordinates: [-97.9, 30.4] },
      tags: ["water_supply", "basin_colorado", "region_lower_colorado"],
      percent_full: 89.2,
      conservation_storage: 979476,
      conservation_capacity: 1098044,
      conservation_pool_elevation: 681,
      elevation: 674.52,
    });

    expect(reservoir).toMatchObject({
      id: "Travis",
      slug: "travis",
      basin: "Colorado",
      region: "Lower Colorado",
      isWaterSupply: true,
      percentFull: 89.2,
    });
  });

  it("rejects records without coordinates", () => {
    expect(normalizeSnapshot("Missing", { short_name: "Missing" })).toBeNull();
  });

  it("creates official-style slugs", () => {
    expect(slugify("B. A. Steinhagen")).toBe("b-a-steinhagen");
    expect(slugify("Lake O' the Pines")).toBe("lake-o-the-pines");
  });
});
