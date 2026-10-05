#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${BACKEND_DIR}"

say() {
  printf '\n==> %s\n' "$1"
}

confirm() {
  local prompt="$1"
  local answer
  read -r -p "${prompt} [y/N] " answer
  [[ "${answer}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

say "Install dependencies"
npm ci

say "Run backend checks"
npm run check

say "Verify Wrangler identity"
npx wrangler whoami
if ! confirm "Does this Wrangler account match the account that should receive the deployment?"; then
  echo "Deployment stopped until Wrangler identity is confirmed."
  exit 1
fi

latest_migration="$(find migrations -maxdepth 1 -type f -name '*.sql' -print | sort | tail -n 1)"
if [[ -n "${latest_migration}" ]]; then
  latest_migration="$(basename -- "${latest_migration}")"
else
  latest_migration="none"
fi

say "Inspect D1 migration state"
echo "Latest migration file in this checkout: ${latest_migration}"
echo "Unapplied remote migrations (Wrangler's authoritative check):"
npx wrangler d1 migrations list texas-water --remote || {
  echo "Unable to list remote migrations. Review the Wrangler error before continuing."
  exit 1
}

echo
echo "Most recently recorded migration (best-effort query):"
if ! npx wrangler d1 execute texas-water --remote --json \
  --command "SELECT id, name, applied_at FROM d1_migrations ORDER BY id DESC LIMIT 1;"; then
  echo "The internal migration-history query was unavailable; the Wrangler migration list above is still authoritative."
fi

if confirm "Apply pending remote D1 migrations now?"; then
  say "Apply remote D1 migrations"
  npx wrangler d1 migrations apply texas-water --remote
else
  echo "Skipping remote D1 migration application."
fi

if ! confirm "Deploy texas-water-api to Cloudflare now?"; then
  echo "Deployment cancelled after checks and migration review."
  exit 0
fi

say "Deploy Worker"
npx wrangler deploy

if confirm "Would you like to trigger a manual reservoir ingestion now?"; then
  cat <<'EOF'

Wrangler does not expose a production scheduled-event invoke command for this
Worker. In the Cloudflare dashboard, open Workers & Pages > texas-water-api >
Settings/Triggers > Cron Triggers and use the available Run now control. The
scheduled handler will write the current reservoir observations to D1.
EOF
  read -r -p "Press Enter after you trigger the scheduled run (or press Enter to continue): " _
else
  echo "No manual ingestion requested; the configured cron will run on schedule."
fi

echo
echo "Deployment flow complete. Run npm run health to verify the public API."
