#!/usr/bin/env bash
set -euo pipefail
APEX_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$APEX_SCRIPT_DIR/tools/docker/build.sh" "$@"
