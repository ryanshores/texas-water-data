import { describe, expect, it } from "vitest";
import { fetchDroughtHydrologyContext } from "../src/hydrology";

describe("drought hydrology context", () => {
  it("normalizes official dates, map URLs, and streamflow percentiles", async () => {
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("soil-moisture/map/current-map-date")) return Response.json("2026-10-02");
      if (url.includes("quick-drought-response-index/current-map-date")) return Response.json("2026-09-27");
      if (url.includes("evaporative-demand-drought-index/map/current-map-date")) return Response.json("2026-09-30");
      if (url.includes("streamflow/daily/info")) {
        return Response.json({ time: { end: "2026-10-04" }, source: { name: "TWDB Surface Water Resources Division" } });
      }
      if (url.includes("streamflow/daily/data")) {
        return Response.json({ data: { value: [2, 10, 40, 70, 90] } });
      }
      return new Response(null, { status: 404 });
    };

    await expect(fetchDroughtHydrologyContext(fetcher)).resolves.toEqual({
      soilMoisture: {
        id: "soil-moisture",
        title: "Root-zone soil moisture",
        mapDate: "2026-10-02",
        mapURL: "https://waterdatafortexas.org/drought/api/soil-moisture/map/2026-10-02",
        description: "SMAP root-zone soil moisture, estimated for the top meter of soil. Values are volumetric water content, not a drought category.",
        sourceName: "Water Data for Texas",
        sourceURL: "https://waterdatafortexas.org/drought/soil-moisture",
      },
      streamflow: {
        observedAt: "2026-10-04",
        gaugeCount: 5,
        medianPercentile: 40,
        belowNormalGaugeCount: 2,
        aboveNormalGaugeCount: 1,
        sourceName: "TWDB Surface Water Resources Division",
        sourceURL: "https://waterdatafortexas.org/drought/streamflow-percentiles/gauges",
      },
      indices: expect.arrayContaining([
        expect.objectContaining({ id: "quickdri", mapDate: "2026-09-27" }),
        expect.objectContaining({ id: "eddi-1-month", mapDate: "2026-09-30" }),
      ]),
    });
  });
});
