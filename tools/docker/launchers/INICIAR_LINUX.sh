#!/usr/bin/env sh
set -eu
APEX_LAUNCH_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$APEX_LAUNCH_DIR"
exec ./APEX_REBOOT.x86_64 "$@"
