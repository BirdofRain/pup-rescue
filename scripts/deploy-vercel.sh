#!/usr/bin/env bash
# Deploy build/web to Vercel production
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$PROJECT_ROOT/build/web" ]]; then
	echo "Missing build/web — run scripts/export-web.sh first" >&2
	exit 1
fi

cd "$PROJECT_ROOT/build/web"
if [[ -n "${VERCEL_TOKEN:-}" ]]; then
	npx vercel deploy --prod --yes --token "$VERCEL_TOKEN"
else
	npx vercel deploy --prod
fi
