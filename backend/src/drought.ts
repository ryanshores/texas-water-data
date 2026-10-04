const DROUGHT_STATE_URL = "https://waterdatafortexas.org/drought/api/drought-monitor/data/state/tx";
const DROUGHT_GEO_URL = "https://waterdatafortexas.org/drought/api/drought-monitor/geo";
const DROUGHT_COUNTY_URL = "https://waterdatafortexas.org/drought/api/drought-monitor/data/county";

export type DroughtCategory = "None" | "D0" | "D1" | "D2" | "D3" | "D4";

export interface DroughtSummary {
  mapDate: string;
  previousMapDate: string | null;
  categories: Record<DroughtCategory, number>;
  weekOverWeek: Record<DroughtCategory, number | null>;
  mapAreas: DroughtMapArea[];
}

export interface DroughtMapArea {
  category: DroughtCategory;
  coordinates: number[][][][];
}

export interface DroughtCountyRecord {
  mapDate: string;
  fips: string;
  county: string;
  state: string;
  categories: Record<DroughtCategory, number>;
}

export async function fetchDroughtSummary(fetcher: typeof fetch = fetch): Promise<DroughtSummary> {
  const [stateResponse, geoResponse] = await Promise.all([
    fetchJSON<unknown[]>(DROUGHT_STATE_URL, fetcher),
    fetchJSON<GeoResponse>(DROUGHT_GEO_URL, fetcher),
  ]);
  const records = stateResponse.filter(isRecord).map(parseStateRecord).filter(isPresent);
  if (records.length === 0) throw new Error("TWDB drought response contained no state records");
  records.sort((a, b) => a.mapDate.localeCompare(b.mapDate));
  const current = records.at(-1)!;
  const previous = records.length > 1 ? records.at(-2) : undefined;
  return {
    mapDate: current.mapDate,
    previousMapDate: previous?.mapDate ?? null,
    categories: current.categories,
    weekOverWeek: difference(current.categories, previous?.categories),
    mapAreas: parseMapAreas(geoResponse),
  };
}

export async function fetchDroughtCounty(
  county: string,
  fetcher: typeof fetch = fetch,
): Promise<DroughtCountyRecord[]> {
  const encoded = encodeURIComponent(county.trim().toLowerCase());
  const response = await fetchJSON<unknown[]>(`${DROUGHT_COUNTY_URL}/${encoded}`, fetcher);
  return response.filter(isRecord).map(parseCountyRecord).filter(isPresent);
}

function parseStateRecord(value: Record<string, unknown>): { mapDate: string; categories: Record<DroughtCategory, number> } | null {
  const mapDate = stringValue(value.MapDate);
  if (!mapDate) return null;
  return { mapDate: formatMapDate(mapDate), categories: categoriesFrom(value) };
}

function parseCountyRecord(value: Record<string, unknown>): DroughtCountyRecord | null {
  const mapDate = stringValue(value.ValidStart) ?? stringValue(value.MapDate);
  const fips = stringValue(value.FIPS);
  const county = stringValue(value.County);
  const state = stringValue(value.State);
  if (!mapDate || !fips || !county || !state) return null;
  return { mapDate: formatMapDate(mapDate), fips, county, state, categories: categoriesFrom(value) };
}

function categoriesFrom(value: Record<string, unknown>): Record<DroughtCategory, number> {
  return {
    None: numberValue(value.None) ?? 0,
    D0: numberValue(value.D0) ?? 0,
    D1: numberValue(value.D1) ?? 0,
    D2: numberValue(value.D2) ?? 0,
    D3: numberValue(value.D3) ?? 0,
    D4: numberValue(value.D4) ?? 0,
  };
}

function difference(current: Record<DroughtCategory, number>, previous?: Record<DroughtCategory, number>): Record<DroughtCategory, number | null> {
  const keys: DroughtCategory[] = ["None", "D0", "D1", "D2", "D3", "D4"];
  return Object.fromEntries(keys.map((key) => [key, previous ? round(current[key] - previous[key]) : null])) as Record<DroughtCategory, number | null>;
}

function parseMapAreas(value: GeoResponse): DroughtMapArea[] {
  return (value.geo_data?.features ?? []).flatMap((feature) => {
    const category = feature.properties?.category;
    const coordinates = feature.geometry?.coordinates;
    return isCategory(category) && Array.isArray(coordinates) ? [{ category, coordinates: coordinates as number[][][][] }] : [];
  });
}

async function fetchJSON<Value>(url: string, fetcher: typeof fetch): Promise<Value> {
  const response = await fetcher(url, { headers: { Accept: "application/json", "User-Agent": "TexasWaterAPI/0.2" } });
  if (!response.ok) throw new Error(`TWDB drought returned HTTP ${response.status}`);
  return await response.json() as Value;
}

function formatMapDate(value: string): string {
  if (/^\d{8}$/.test(value)) return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
  return value;
}

function round(value: number): number { return Math.round(value * 100) / 100; }
function stringValue(value: unknown): string | null { return typeof value === "string" && value.length > 0 ? value : null; }
function numberValue(value: unknown): number | null { return typeof value === "number" && Number.isFinite(value) ? value : null; }
function isPresent<Value>(value: Value | null): value is Value { return value !== null; }
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function isCategory(value: unknown): value is DroughtCategory { return value === "None" || value === "D0" || value === "D1" || value === "D2" || value === "D3" || value === "D4"; }

interface GeoResponse {
  geo_data?: { features?: Array<{ properties?: { category?: unknown }; geometry?: { coordinates?: unknown } }> };
}
