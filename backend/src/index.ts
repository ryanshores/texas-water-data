import { readDashboard, readHistory, upsertCurrentConditions } from "./database";
import { normalizeSnapshot } from "./normalize";

const TWDB_CURRENT_URL = "https://waterdatafortexas.org/reservoirs/recent-conditions.json";

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
    const response = await fetch(TWDB_CURRENT_URL, {
      headers: { "User-Agent": "TexasWaterAPI/0.1" },
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) throw new Error(`TWDB returned HTTP ${response.status}`);
    const contentLength = Number(response.headers.get("content-length") ?? "0");
    if (contentLength > 2_000_000) throw new Error("TWDB response exceeded size limit");
    const body: unknown = await response.json();
    if (!isRecord(body)) throw new Error("TWDB response was not an object");

    const reservoirs = Object.entries(body)
      .map(([id, value]) => normalizeSnapshot(id, value))
      .filter((value) => value !== null);
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
