const WELLS_URL = "https://waterdatafortexas.org/groundwater/wells.geojson";
const RECENT_URL = "https://waterdatafortexas.org/groundwater/recent-conditions.json";
const WELL_URL = "https://waterdatafortexas.org/groundwater/well";

export interface GroundwaterWell {
  id: string;
  county: string;
  aquifer: string;
  aquiferType: string | null;
  status: string;
  latitude: number;
  longitude: number;
  observedAt: string | null;
  depthBelowLandSurface: number | null;
}

export interface GroundwaterReading {
  date: string;
  depthBelowLandSurface: number;
}

export async function fetchGroundwaterWells(fetcher: typeof fetch = fetch): Promise<GroundwaterWell[]> {
  const [metadata, recent] = await Promise.all([fetchJSON<GeoJSON>(WELLS_URL, fetcher), fetchJSON<RecentPayload>(RECENT_URL, fetcher)]);
  const latest = new Map(recent.values.map((value) => [value.state_well_number, value]));
  return metadata.features.flatMap((feature) => {
    const properties = feature.properties;
    const coordinates = feature.geometry?.coordinates;
    if (!properties || !coordinates || coordinates.length < 2) return [];
    const id = stringValue(properties.well_number);
    const county = stringValue(properties.county);
    const aquifer = stringValue(properties.aquifer);
    const latitude = numberValue(coordinates[1]);
    const longitude = numberValue(coordinates[0]);
    if (!id || !county || !aquifer || latitude === null || longitude === null) return [];
    const observation = latest.get(id);
    return [{
      id, county, aquifer, latitude, longitude,
      aquiferType: stringValue(properties.aquifer_type), status: stringValue(properties.status) ?? "Unknown",
      observedAt: observation?.date ?? null,
      depthBelowLandSurface: observation ? numberValue(observation["daily_high_water_level(ft below land surface)"]) : null,
    }];
  }).sort((left, right) => left.county.localeCompare(right.county) || left.id.localeCompare(right.id));
}

export async function fetchGroundwaterHistory(id: string, fetcher: typeof fetch = fetch): Promise<GroundwaterReading[]> {
  if (!/^\d{7}$/.test(id)) throw new Error("Invalid state well number");
  const payload = await fetchJSON<HistoryPayload>(`${WELL_URL}/${id}.json`, fetcher);
  const daily = new Map<string, { total: number; count: number }>();
  payload.values.flatMap((value) => {
    const date = stringValue(value.datetime)?.slice(0, 10);
    const depth = numberValue(value["water_level(ft below land surface)"]);
    return date && depth !== null ? [{ date, depth }] : [];
  }).forEach(({ date, depth }) => {
    const current = daily.get(date) ?? { total: 0, count: 0 };
    current.total += depth;
    current.count += 1;
    daily.set(date, current);
  });
  return [...daily.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .slice(-730)
    .map(([date, value]) => ({ date, depthBelowLandSurface: value.total / value.count }));
}

async function fetchJSON<T>(url: string, fetcher: typeof fetch): Promise<T> {
  const response = await fetcher(url, { headers: { Accept: "application/json" } });
  if (!response.ok) throw new Error(`TWDB groundwater returned HTTP ${response.status}`);
  return response.json() as Promise<T>;
}
function stringValue(value: unknown): string | null { return typeof value === "string" && value.trim() ? value.trim() : null; }
function numberValue(value: unknown): number | null { return typeof value === "number" && Number.isFinite(value) ? value : null; }
interface GeoJSON { features: Array<{ geometry?: { coordinates?: unknown[] }; properties?: Record<string, unknown> }>; }
interface RecentPayload { values: Array<{ state_well_number: string; date: string; "daily_high_water_level(ft below land surface)": unknown }>; }
interface HistoryPayload { values: Array<Record<string, unknown>>; }
