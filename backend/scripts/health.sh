#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${TEXAS_WATER_API_BASE_URL:-https://texas-water-api.ryan-shores.workers.dev}"
BASE_URL="${BASE_URL%/}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

fetch_json() {
  local name="$1"
  local path="$2"
  local output="${TEMP_DIR}/${name}.json"
  local status

  printf '%-24s' "${name}" >&2
  if ! status="$(curl --silent --show-error --location \
    --connect-timeout 10 --max-time 45 \
    --output "${output}" --write-out '%{http_code}' \
    "${BASE_URL}${path}")"; then
    echo "FAIL (request error)" >&2
    return 1
  fi
  if [[ ! "${status}" =~ ^2[0-9][0-9]$ ]]; then
    echo "FAIL (HTTP ${status})" >&2
    sed -n '1,3p' "${output}" >&2 || true
    return 1
  fi
  echo "HTTP ${status}" >&2
  printf '%s' "${output}"
}

validate() {
  local name="$1"
  local file="$2"
  node - "${name}" "${file}" <<'NODE'
const fs = require("node:fs");

const [name, file] = process.argv.slice(2);
const value = JSON.parse(fs.readFileSync(file, "utf8"));
const isObject = (item) => item !== null && typeof item === "object" && !Array.isArray(item);
const isString = (item) => typeof item === "string" && item.length > 0;
const isArray = (item) => Array.isArray(item) && item.length > 0;
const fail = (message) => {
  console.error(`FAIL (${name}: ${message})`);
  process.exit(1);
};

switch (name) {
  case "health":
    if (value?.status !== "ok") fail("status is not ok");
    break;
  case "dashboard":
    if (!isString(value?.generatedAt)) fail("missing generatedAt");
    if (!isArray(value?.reservoirs)) fail("reservoirs is empty or missing");
    if (!isString(value.reservoirs[0]?.id)) fail("first reservoir has no id");
    break;
  case "drought":
    if (!isString(value?.mapDate)) fail("missing mapDate");
    if (!isObject(value?.categories) || !["None", "D0", "D1", "D2", "D3", "D4"].every((key) => typeof value.categories[key] === "number")) {
      fail("category percentages are incomplete");
    }
    if (!Array.isArray(value?.mapAreas)) fail("mapAreas is missing");
    break;
  case "context":
    if (!isString(value?.soilMoisture?.mapURL)) fail("soil moisture map is missing");
    if (!Number.isFinite(value?.streamflow?.gaugeCount)) fail("streamflow gauge count is missing");
    if (!Array.isArray(value?.indices) || value.indices.length < 2) fail("drought index layers are incomplete");
    break;
  case "counties":
    if (!isArray(value?.counties) || !isString(value.counties[0]?.county)) fail("county catalog is empty or malformed");
    break;
  case "county-detail":
    if (!Array.isArray(value?.records)) fail("county records are missing");
    break;
  case "history-30d":
  case "history-1y":
    if (!isArray(value) || !isString(value[0]?.date)) fail("history is empty or malformed");
    break;
  default:
    fail("unknown validation target");
}

console.log(`PASS (${name})`);
NODE
}

echo "Checking ${BASE_URL}"

health_file="$(fetch_json health /health)"
validate health "${health_file}"

dashboard_file="$(fetch_json dashboard /v1/dashboard)"
validate dashboard "${dashboard_file}"
reservoir_id="$(node - "${dashboard_file}" <<'NODE'
const fs = require("node:fs");
const value = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(encodeURIComponent(value.reservoirs[0].id));
NODE
)"

drought_file="$(fetch_json drought /v1/drought)"
validate drought "${drought_file}"

context_file="$(fetch_json context /v1/drought/context)"
validate context "${context_file}"

counties_file="$(fetch_json counties /v1/drought/counties)"
validate counties "${counties_file}"
county_name="$(node - "${counties_file}" <<'NODE'
const fs = require("node:fs");
const value = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(encodeURIComponent(value.counties[0].county));
NODE
)"

county_detail_file="$(fetch_json county-detail "/v1/drought/counties/${county_name}")"
validate county-detail "${county_detail_file}"

history_30d_file="$(fetch_json history-30d "/v1/reservoirs/${reservoir_id}/history?range=30d")"
validate history-30d "${history_30d_file}"

history_1y_file="$(fetch_json history-1y "/v1/reservoirs/${reservoir_id}/history?range=1y")"
validate history-1y "${history_1y_file}"

echo
echo "All API endpoint checks passed."
