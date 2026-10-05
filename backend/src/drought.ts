const DROUGHT_STATE_URL = "https://waterdatafortexas.org/drought/api/drought-monitor/data/state/tx";
const DROUGHT_GEO_URL = "https://waterdatafortexas.org/drought/api/drought-monitor/geo";
const DROUGHT_COUNTY_URL = "https://waterdatafortexas.org/drought/api/drought-monitor/data/county";
const COUNTIES_GEOMETRY_URL = "https://waterdatafortexas.org/drought/api/geometries/counties";

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

export interface DroughtCountyBoundary {
  fips: string;
  county: string;
  coordinates: number[][][];
}

export interface DroughtCountyDetail {
  county: string;
  records: DroughtCountyRecord[];
  boundary: DroughtCountyBoundary | null;
}

export interface DroughtCountyCatalogEntry {
  fips: string;
  county: string;
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

export async function fetchDroughtCountyDetail(
  county: string,
  fetcher: typeof fetch = fetch,
): Promise<DroughtCountyDetail> {
  const [records, topology] = await Promise.all([
    fetchDroughtCounty(county, fetcher),
    fetchJSON<Topology>(COUNTIES_GEOMETRY_URL, fetcher),
  ]);
  const canonicalName = records.at(-1)?.county ?? `${county.trim()} County`;
  return { county, records, boundary: countyBoundary(topology, canonicalName) };
}

export async function fetchDroughtCountyCatalog(
  fetcher: typeof fetch = fetch,
): Promise<DroughtCountyCatalogEntry[]> {
  const topology = await fetchJSON<Topology>(COUNTIES_GEOMETRY_URL, fetcher);
  const geometries = topology.objects?.counties?.geometries ?? [];
  return geometries.flatMap((geometry) => {
    const county = stringValue(geometry.properties?.name);
    const fips = stringValue(geometry.id);
    return county && fips ? [{ county, fips }] : [];
  }).sort((left, right) => left.county.localeCompare(right.county));
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

export function countyBoundary(topology: Topology, county: string): DroughtCountyBoundary | null {
  const geometries = topology.objects?.counties?.geometries ?? [];
  const geometry = geometries.find((candidate) => stringValue(candidate.properties?.name)?.toLowerCase() === county.toLowerCase());
  const fips = geometry && stringValue(geometry.id);
  if (!geometry || !fips || geometry.type !== "Polygon" || !Array.isArray(geometry.arcs)) return null;

  const transform = topology.transform;
  const arcs = topology.arcs;
  if (!transform || !Array.isArray(arcs)) return null;
  const coordinates = geometry.arcs.flatMap((ring) => Array.isArray(ring) ? [joinArcs(ring, arcs, transform)] : []);
  return coordinates.length > 0 ? { fips, county, coordinates } : null;
}

function joinArcs(indices: unknown[], arcs: unknown[], transform: TopologyTransform): number[][] {
  const ring: number[][] = [];
  for (const indexValue of indices) {
    if (typeof indexValue !== "number") continue;
    const arcIndex = indexValue < 0 ? -indexValue - 1 : indexValue;
    const rawArc = arcs[arcIndex];
    if (!Array.isArray(rawArc)) continue;
    const decoded = decodeArc(rawArc, transform);
    const oriented = indexValue < 0 ? decoded.reverse() : decoded;
    ring.push(...(ring.length > 0 ? oriented.slice(1) : oriented));
  }
  return ring;
}

function decodeArc(rawArc: unknown[], transform: TopologyTransform): number[][] {
  let x = 0;
  let y = 0;
  return rawArc.flatMap((step) => {
    if (!Array.isArray(step) || typeof step[0] !== "number" || typeof step[1] !== "number") return [];
    x += step[0];
    y += step[1];
    return [[x * transform.scale[0] + transform.translate[0], y * transform.scale[1] + transform.translate[1]]];
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

interface Topology {
  transform?: TopologyTransform;
  arcs?: unknown[];
  objects?: {
    counties?: {
      geometries?: Array<{
        id?: unknown;
        type?: unknown;
        properties?: { name?: unknown };
        arcs?: unknown;
      }>;
    };
  };
}

interface TopologyTransform {
  scale: [number, number];
  translate: [number, number];
}
