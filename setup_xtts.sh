#!/usr/bin/env bash
# Convenience wrapper for Coqui XTTS setup in the InsightIOS repo.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
exec bash "$SCRIPT_DIR/tools/xtts/setup_mac.sh" "$@"
