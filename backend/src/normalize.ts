export interface NormalizedReservoir {
  id: string;
  slug: string;
  shortName: string;
  fullName: string;
  observedAt: string;
  latitude: number;
  longitude: number;
  basin: string | null;
  region: string | null;
  isWaterSupply: boolean;
  isFloodControl: boolean;
  percentFull: number | null;
  elevation: number | null;
  surfaceArea: number | null;
  reservoirStorage: number | null;
  conservationStorage: number | null;
  conservationCapacity: number | null;
  conservationPoolElevation: number | null;
  deadPoolCapacity: number | null;
}

export function normalizeSnapshot(id: string, value: unknown): NormalizedReservoir | null {
  if (!isRecord(value)) return null;
  const shortName = stringValue(value.short_name);
  const fullName = stringValue(value.full_name);
  const observedAt = stringValue(value.timestamp);
  const condensedName = stringValue(value.condensed_name) ?? id;
  const gauge = isRecord(value.gauge_location) ? value.gauge_location : null;
  const coordinates = gauge && Array.isArray(gauge.coordinates) ? gauge.coordinates : [];
  const longitude = numberValue(coordinates[0]);
  const latitude = numberValue(coordinates[1]);
  if (!shortName || !fullName || !observedAt || latitude === null || longitude === null) return null;

  const tags = Array.isArray(value.tags)
    ? value.tags.filter((tag): tag is string => typeof tag === "string")
    : [];

  return {
    id: condensedName,
    slug: slugify(shortName),
    shortName,
    fullName,
    observedAt,
    latitude,
    longitude,
    basin: displayTag(tags.find((tag) => tag.startsWith("basin_"))),
    region: displayTag(tags.find((tag) => tag.startsWith("region_"))),
    isWaterSupply: tags.includes("water_supply"),
    isFloodControl: value.flood_control_lake === "Y",
    percentFull: numberValue(value.percent_full),
    elevation: numberValue(value.elevation),
    surfaceArea: numberValue(value.area),
    reservoirStorage: numberValue(value.volume),
    conservationStorage: numberValue(value.conservation_storage),
    conservationCapacity: numberValue(value.conservation_capacity),
    conservationPoolElevation: numberValue(value.conservation_pool_elevation),
    deadPoolCapacity: numberValue(value.dead_pool_capacity),
  };
}

export function slugify(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function extractOfficialSlugMap(html: string): Map<string, string> {
  const links = html.matchAll(
    /<a\s+[^>]*href=["']\/reservoirs\/individual\/([^"'?#/]+)["'][^>]*>([^<]+)<\/a>/gi,
  );
  const slugs = new Map<string, string>();
  for (const link of links) {
    const slug = link[1];
    const name = link[2];
    if (slug && name) slugs.set(slugify(decodeHTMLEntities(name)), slug);
  }
  return slugs;
}

function displayTag(tag: string | undefined): string | null {
  if (!tag) return null;
  return tag
    .split("_")
    .slice(1)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function numberValue(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function decodeHTMLEntities(value: string): string {
  return value
    .replaceAll("&#39;", "'")
    .replaceAll("&apos;", "'")
    .replaceAll("&quot;", '"')
    .replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">");
}
