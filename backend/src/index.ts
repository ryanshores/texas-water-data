import { readDashboard, readHistory, upsertCurrentConditions } from "./database";
import { fetchDroughtCountyCatalog, fetchDroughtCountyDetail, fetchDroughtSummary } from "./drought";
import { fetchDroughtHydrologyContext } from "./hydrology";
import { extractOfficialSlugMap, normalizeSnapshot, slugify } from "./normalize";

const TWDB_CURRENT_URL = "https://waterdatafortexas.org/reservoirs/recent-conditions.json";
const TWDB_STATEWIDE_URL = "https://waterdatafortexas.org/reservoirs/statewide";

export default {
  async fetch(request, env): Promise<Response> {
    try {
      const url = new URL(request.url);
      if (request.method !== "GET") return json({ error: "Method not allowed" }, 405);
      if (url.pathname === "/health") return json({ status: "ok" });
      if (url.pathname === "/v1/dashboard") {
        const dashboard = await readDashboard(env.DB);
        if (dashboard.reservoirs.length === 0) {
          return json({ error: "Reservoir ingestion has not completed" }, 503, {
            "Retry-After": "300",
          });
        }
        return json(dashboard, 200, { "Cache-Control": "public, max-age=300" });
      }

      if (url.pathname === "/v1/drought") {
        return json(await fetchDroughtSummary(), 200, { "Cache-Control": "public, max-age=900" });
      }

      if (url.pathname === "/v1/drought/context") {
        return json(await fetchDroughtHydrologyContext(), 200, { "Cache-Control": "public, max-age=900" });
      }

      if (url.pathname === "/v1/drought/counties") {
        return json({ counties: await fetchDroughtCountyCatalog() }, 200, {
          "Cache-Control": "public, max-age=86400",
        });
      }

      const droughtCountyMatch = url.pathname.match(/^\/v1\/drought\/counties\/([^/]+)$/);
      if (droughtCountyMatch) {
        const county = decodeURIComponent(droughtCountyMatch[1] ?? "");
        return json(await fetchDroughtCountyDetail(county), 200, {
          "Cache-Control": "public, max-age=900",
        });
      }

      const historyMatch = url.pathname.match(/^\/v1\/reservoirs\/([^/]+)\/history$/);
      if (historyMatch) {
        const reservoirID = decodeURIComponent(historyMatch[1] ?? "");
        const days = url.searchParams.get("range") === "30d" ? 30 : 366;
        return json(await readHistory(env.DB, reservoirID, days), 200, {
          "Cache-Control": "public, max-age=3600",
        });
      }
      return json({ error: "Not found" }, 404);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(JSON.stringify({ message: "request failed", error: message }));
      return json({ error: "Internal server error" }, 500);
    }
  },

  async scheduled(controller, env): Promise<void> {
    try {
      const count = await ingestCurrentConditions(env.DB);
      console.log(JSON.stringify({
        message: "reservoir ingestion complete",
        count,
        cron: controller.cron,
        scheduledTime: controller.scheduledTime,
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(JSON.stringify({ message: "reservoir ingestion failed", error: message }));
      throw error;
    }
  },
} satisfies ExportedHandler<Env>;

export async function ingestCurrentConditions(db: D1Database): Promise<number> {
  const runID = crypto.randomUUID();
  const startedAt = new Date().toISOString();
  await db.prepare(
    "INSERT INTO ingestion_runs (id, started_at, status) VALUES (?, ?, 'running')",
  ).bind(runID, startedAt).run();

  try {
    const [currentText, statewideHTML] = await Promise.all([
      fetchTWDBText(TWDB_CURRENT_URL, 2_000_000),
      fetchTWDBText(TWDB_STATEWIDE_URL, 2_000_000),
    ]);
    const body: unknown = JSON.parse(currentText);
    if (!isRecord(body)) throw new Error("TWDB response was not an object");
    const officialSlugs = extractOfficialSlugMap(statewideHTML);
    if (officialSlugs.size < 100) {
      throw new Error(`TWDB statewide page contained only ${officialSlugs.size} official slugs`);
    }

    const normalized = Object.entries(body)
      .map(([id, value]) => normalizeSnapshot(id, value))
      .filter((value) => value !== null);
    const missingSlugs = normalized.filter((reservoir) => !officialSlugs.has(slugify(reservoir.shortName)));
    if (missingSlugs.length > 0) {
      throw new Error(`TWDB statewide page did not map ${missingSlugs.length} reservoir names`);
    }
    const reservoirs = normalized.map((reservoir) => ({
      ...reservoir,
      slug: officialSlugs.get(slugify(reservoir.shortName))!,
    }));
    if (reservoirs.length < 100) throw new Error(`TWDB response contained only ${reservoirs.length} valid records`);

    await upsertCurrentConditions(db, reservoirs);
    await db.prepare(`
      UPDATE ingestion_runs SET completed_at = ?, status = 'complete', record_count = ? WHERE id = ?
    `).bind(new Date().toISOString(), reservoirs.length, runID).run();
    return reservoirs.length;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await db.prepare(`
      UPDATE ingestion_runs SET completed_at = ?, status = 'failed', error = ? WHERE id = ?
    `).bind(new Date().toISOString(), message, runID).run();
    throw error;
  }
}

async function fetchTWDBText(url: string, sizeLimit: number): Promise<string> {
  const response = await fetch(url, {
    headers: { "User-Agent": "TexasWaterAPI/0.1" },
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error(`TWDB returned HTTP ${response.status} for ${url}`);
  const contentLength = Number(response.headers.get("content-length") ?? "0");
  if (contentLength > sizeLimit) throw new Error(`TWDB response exceeded size limit for ${url}`);
  if (!response.body) throw new Error(`TWDB returned an empty response body for ${url}`);

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > sizeLimit) {
        await reader.cancel("TWDB response exceeded size limit");
        throw new Error(`TWDB response exceeded size limit for ${url}`);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const body = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(body);
}

function json(body: object, status = 200, headers: Record<string, string> = {}): Response {
  return Response.json(body, {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
      ...headers,
    },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
