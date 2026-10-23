#!/usr/bin/env bash
set -euo pipefail
APEX_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$APEX_SCRIPT_DIR/godot.lock"
APEX_PROJECT_DIR=${APEX_PROJECT_DIR:-$(cd "$APEX_SCRIPT_DIR/../.." && pwd)}
APEX_OUTPUT_DIR=${APEX_OUTPUT_DIR:-$APEX_PROJECT_DIR/build}
APEX_GODOT_BIN=${APEX_GODOT_BIN:-/opt/godot/bin/godot}
APEX_TEMPLATE_ROOT=${APEX_TEMPLATE_ROOT:-/opt/godot/export_templates}
APEX_STATE="${APEX_CACHE_ROOT:-/cache}/uid-$(id -u)"
APEX_TARGET=${1:-all}
case "$APEX_TARGET" in all|windows|linux|web) ;; *) echo 'Uso: build [all|windows|linux|web]' >&2; exit 2 ;; esac
[[ $# -le 1 ]] || { echo 'Indica un solo destino o all.' >&2; exit 2; }
[[ -f "$APEX_PROJECT_DIR/project.godot" ]] || { echo 'Falta project.godot.' >&2; exit 1; }
[[ -w "$APEX_PROJECT_DIR" ]] || { echo 'Sin permiso de escritura. En Linux usa tools/docker/build.sh para ajustar UID/GID.' >&2; exit 1; }
APEX_ENGINE_VERSION=$("$APEX_GODOT_BIN" --headless --version)
[[ $APEX_ENGINE_VERSION == "$APEX_GODOT_VERSION.stable"* ]] || { echo 'Version de Godot distinta del lock. Ejecuta docker compose build build.' >&2; exit 1; }
export XDG_DATA_HOME="$APEX_STATE/data"
export XDG_CONFIG_HOME="$APEX_STATE/config"
export XDG_CACHE_HOME="$APEX_STATE/cache"
mkdir -p "$XDG_DATA_HOME/godot" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$APEX_OUTPUT_DIR/logs"
if [[ ! -e "$XDG_DATA_HOME/godot/export_templates" ]]; then
  ln -s "$APEX_TEMPLATE_ROOT" "$XDG_DATA_HOME/godot/export_templates"
fi
touch "$APEX_OUTPUT_DIR/.gdignore"
cd "$APEX_PROJECT_DIR"
run_godot() {
  local log="$APEX_OUTPUT_DIR/logs/$1.log"
  shift
  if ! "$APEX_GODOT_BIN" --headless --path "$APEX_PROJECT_DIR" "$@" 2>&1 | tee "$log"; then
    echo "Godot no pudo completar la etapa. Revisa $log" >&2; return 1
  fi
  if grep -Eq '(SCRIPT ERROR:|ERROR:)' "$log"; then
    echo "Godot registro errores. Se detiene la compilacion: $log" >&2; return 1
  fi
}
run_godot import --import
export_target() {
  local target=$1 preset=$2 filename=$3 folder="$APEX_OUTPUT_DIR/$1"
  mkdir -p "$folder"
  run_godot "export_$target" --export-release "$preset" "$folder/$filename"
  [[ -s "$folder/$filename" ]] || { echo "No se genero $filename." >&2; return 1; }
  if [[ $target == Web ]]; then
    [[ -s "$folder/index.wasm" && -s "$folder/index.pck" ]] || { echo 'Falta WASM o PCK de Web.' >&2; return 1; }
  else
    [[ -s "$folder/APEX_REBOOT.pck" ]] || { echo "Falta el PCK de $target." >&2; return 1; }
  fi
  bash "$APEX_SCRIPT_DIR/package-notices.sh" "$APEX_PROJECT_DIR" "$folder" "$target"
  printf 'Godot=%s\nEditorArchiveSHA512=%s\nTemplatesArchiveSHA512=%s\nTarget=%s\n' \
    "$APEX_ENGINE_VERSION" "$APEX_EDITOR_SHA512" "$APEX_TEMPLATES_SHA512" "$target" > "$folder/BUILD_INFO.txt"
}
if [[ $APEX_TARGET == all || $APEX_TARGET == windows ]]; then
  export_target Windows 'Windows Desktop' APEX_REBOOT.exe
fi
if [[ $APEX_TARGET == all || $APEX_TARGET == linux ]]; then
  export_target Linux Linux APEX_REBOOT.x86_64
  chmod +x "$APEX_OUTPUT_DIR/Linux/APEX_REBOOT.x86_64"
fi
if [[ $APEX_TARGET == all || $APEX_TARGET == web ]]; then
  export_target Web Web index.html
fi
echo "Compilacion terminada: $APEX_OUTPUT_DIR ($APEX_TARGET)."
