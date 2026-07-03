#!/usr/bin/env bash
# Export Godot web build and deploy to Vercel (requires: vercel login once, or VERCEL_TOKEN)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/export-web.sh"
bash "$SCRIPT_DIR/deploy-vercel.sh"
