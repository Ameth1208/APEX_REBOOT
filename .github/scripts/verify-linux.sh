#!/usr/bin/env bash
set -euo pipefail
APEX_PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
APEX_GODOT_BIN=${APEX_GODOT_BIN:-/opt/godot/bin/godot}
APEX_CI_STATE="${APEX_CACHE_ROOT:-/cache}/ci-uid-$(id -u)"
export XDG_DATA_HOME="$APEX_CI_STATE/data"
export XDG_CONFIG_HOME="$APEX_CI_STATE/config"
export XDG_CACHE_HOME="$APEX_CI_STATE/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
cd "$APEX_PROJECT_DIR"
mkdir -p build/logs
run_check() {
  local label=$1 log="$APEX_PROJECT_DIR/build/logs/ci_$1.log"
  shift
  if ! timeout 180s "$@" 2>&1 | tee "$log"; then
    echo "Fallo de ejecución o timeout: $label" >&2
    return 1
  fi
  if grep -Eq '(SCRIPT ERROR:|ERROR:|FAIL:)' "$log"; then
    echo "El registro contiene errores: $log" >&2
    return 1
  fi
}
for APEX_CHECK in physics_checks vehicle_condition_checks collision_checks aero_wake_checks \
  race_rules_checks ai_traffic_checks wheel_rig_checks formula_handling_checks \
  performance_checks track_finish_checks ui_editing_checks; do
  run_check "$APEX_CHECK" "$APEX_GODOT_BIN" --headless --path . --fixed-fps 120 --script "tests/$APEX_CHECK.gd"
done
(
  cd "$APEX_PROJECT_DIR/build/Linux"
  run_check linux_start ./APEX_REBOOT.x86_64 --headless --quit-after 120
)
echo 'Verificación Linux terminada; no se ha probado el renderizado ni un dispositivo de entrada.'
