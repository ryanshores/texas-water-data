import { describe, expect, it } from "vitest";
import { countyBoundary, fetchDroughtSummary } from "../src/drought";

describe("drought source normalization", () => {
  it("returns the latest state record and week-over-week deltas", async () => {
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      if (url.endsWith("/geo")) {
        return Response.json({
          map_date: "2026-09-29",
          geo_data: { features: [{ properties: { category: "D1" }, geometry: { coordinates: [[[[1, 2]]]] } }] },
        });
      }
      return Response.json([
        { MapDate: "20260922", None: 50, D0: 30, D1: 10, D2: 2, D3: 0, D4: 0 },
        { MapDate: "20260929", None: 48, D0: 32.5, D1: 12, D2: 2, D3: 0.5, D4: 0 },
      ]);
    };

    await expect(fetchDroughtSummary(fetcher)).resolves.toEqual({
      mapDate: "2026-09-29",
      previousMapDate: "2026-09-22",
      categories: { None: 48, D0: 32.5, D1: 12, D2: 2, D3: 0.5, D4: 0 },
      weekOverWeek: { None: -2, D0: 2.5, D1: 2, D2: 0, D3: 0.5, D4: 0 },
      mapAreas: [{ category: "D1", coordinates: [[[[1, 2]]]] }],
    });
  });
});

describe("county topology normalization", () => {
  it("joins transformed arcs into the official county boundary", () => {
    const boundary = countyBoundary({
      transform: { scale: [0.1, 0.1], translate: [-100, 30] },
      arcs: [
        [[0, 0], [10, 0]],
        [[10, 0], [0, 10]],
        [[10, 10], [-10, 0]],
        [[0, 10], [0, -10]],
      ],
      objects: {
        counties: {
          geometries: [{
            id: "48453",
            type: "Polygon",
            properties: { name: "Travis County" },
            arcs: [[0, 1, 2, 3]],
          }],
        },
      },
    }, "Travis County");

    expect(boundary).toEqual({
      fips: "48453",
      county: "Travis County",
      coordinates: [[[-100, 30], [-99, 30], [-99, 31], [-100, 31], [-100, 30]]],
    });
  });
});
