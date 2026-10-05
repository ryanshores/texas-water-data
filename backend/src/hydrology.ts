const ROOT_URL = "https://waterdatafortexas.org/drought";
const SOIL_MOISTURE_DATE_URL = `${ROOT_URL}/api/soil-moisture/map/current-map-date`;
const STREAMFLOW_INFO_URL = `${ROOT_URL}/streamflow/daily/info`;
const STREAMFLOW_DATA_URL = `${ROOT_URL}/streamflow/daily/data`;
const QUICK_DRI_DATE_URL = `${ROOT_URL}/api/quick-drought-response-index/current-map-date`;
const EDDI_DATE_URL = `${ROOT_URL}/api/evaporative-demand-drought-index/map/current-map-date`;

export interface DroughtRasterLayer {
  id: string;
  title: string;
  mapDate: string;
  mapURL: string;
  description: string;
  sourceName: string;
  sourceURL: string;
}

export interface StreamflowSummary {
  observedAt: string;
  gaugeCount: number;
  medianPercentile: number | null;
  belowNormalGaugeCount: number;
  aboveNormalGaugeCount: number;
  sourceName: string;
  sourceURL: string;
}

export interface DroughtHydrologyContext {
  soilMoisture: DroughtRasterLayer;
  streamflow: StreamflowSummary;
  indices: DroughtRasterLayer[];
}

/**
 * Returns official, state-wide drought context. Raster URLs stay on the TWDB
 * site so the app can show the original dated map and source attribution.
 */
export async function fetchDroughtHydrologyContext(
  fetcher: typeof fetch = fetch,
): Promise<DroughtHydrologyContext> {
  const [soilMoistureDate, streamflowInfo, quickDRIDate, eddiDate] = await Promise.all([
    fetchJSON<string>(SOIL_MOISTURE_DATE_URL, fetcher),
    fetchJSON<StreamflowInfo>(STREAMFLOW_INFO_URL, fetcher),
    fetchJSON<string>(QUICK_DRI_DATE_URL, fetcher),
    fetchJSON<string>(EDDI_DATE_URL, fetcher),
  ]);
  const observedAt = stringValue(streamflowInfo.time?.end);
  if (!observedAt) throw new Error("TWDB streamflow metadata did not include an observation date");

  const streamflowDataURL = new URL(STREAMFLOW_DATA_URL);
  streamflowDataURL.searchParams.set("start", observedAt);
  streamflowDataURL.searchParams.set("end", observedAt);
  const streamflowPayload = await fetchJSON<StreamflowPayload>(streamflowDataURL.toString(), fetcher);

  return {
    soilMoisture: rasterLayer({
      id: "soil-moisture",
      title: "Root-zone soil moisture",
      mapDate: requiredDate(soilMoistureDate, "soil moisture"),
      mapPath: `/api/soil-moisture/map/${soilMoistureDate}`,
      description: "SMAP root-zone soil moisture, estimated for the top meter of soil. Values are volumetric water content, not a drought category.",
      sourceURL: `${ROOT_URL}/soil-moisture`,
    }),
    streamflow: summarizeStreamflow(streamflowPayload, observedAt, streamflowInfo),
    indices: [
      rasterLayer({
        id: "quickdri",
        title: "QuickDRI",
        mapDate: requiredDate(quickDRIDate, "QuickDRI"),
        mapPath: `/api/quick-drought-response-index/map/${quickDRIDate}`,
        description: "A weekly indicator for rapid-onset, or flash, drought and short-term landscape dryness.",
        sourceURL: `${ROOT_URL}/quick-drought-response-index`,
      }),
      rasterLayer({
        id: "eddi-1-month",
        title: "Evaporative demand drought index",
        mapDate: requiredDate(eddiDate, "EDDI"),
        mapPath: `/api/evaporative-demand-drought-index/map/${eddiDate}/1-month`,
        description: "One-month EDDI shows unusual atmospheric thirst; warmer drought colors indicate higher evaporative demand.",
        sourceURL: `${ROOT_URL}/evaporative-demand-drought-index`,
      }),
    ],
  };
}

function rasterLayer({
  id,
  title,
  mapDate,
  mapPath,
  description,
  sourceURL,
}: {
  id: string;
  title: string;
  mapDate: string;
  mapPath: string;
  description: string;
  sourceURL: string;
}): DroughtRasterLayer {
  return {
    id,
    title,
    mapDate,
    mapURL: `${ROOT_URL}${mapPath}`,
    description,
    sourceName: "Water Data for Texas",
    sourceURL,
  };
}

function summarizeStreamflow(
  payload: StreamflowPayload,
  observedAt: string,
  info: StreamflowInfo,
): StreamflowSummary {
  const values = (payload.data?.value ?? []).filter(isFiniteNumber);
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  let medianPercentile: number | null = null;
  if (sorted.length > 0) {
    medianPercentile = sorted.length % 2 === 0
      ? round((sorted[middle - 1]! + sorted[middle]!) / 2)
      : sorted[middle]!;
  }
  const sourceName = stringValue(info.source?.name) ?? "TWDB Surface Water Resources Division";

  return {
    observedAt,
    gaugeCount: values.length,
    medianPercentile,
    belowNormalGaugeCount: values.filter((value) => value < 25).length,
    aboveNormalGaugeCount: values.filter((value) => value > 75).length,
    sourceName,
    sourceURL: `${ROOT_URL}/streamflow-percentiles/gauges`,
  };
}

async function fetchJSON<Value>(url: string, fetcher: typeof fetch): Promise<Value> {
  const response = await fetcher(url, {
    headers: { Accept: "application/json", "User-Agent": "TexasWaterAPI/0.3" },
  });
  if (!response.ok) throw new Error(`TWDB hydrology returned HTTP ${response.status}`);
  return await response.json() as Value;
}

function requiredDate(value: string, layer: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new Error(`TWDB ${layer} returned an invalid map date`);
  return value;
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}

interface StreamflowInfo {
  time?: { end?: unknown };
  source?: { name?: unknown };
}

interface StreamflowPayload {
  data?: { value?: unknown[] };
}
