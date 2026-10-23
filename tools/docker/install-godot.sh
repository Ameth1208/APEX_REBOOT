#!/usr/bin/env bash
set -euo pipefail
APEX_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$APEX_SCRIPT_DIR/godot.lock"
APEX_PREFIX=${1:-/opt/godot}
APEX_DOWNLOADS=${2:-/tmp/apex-godot-downloads}
APEX_REMOTE="https://github.com/godotengine/godot/releases/download/$APEX_GODOT_VERSION-stable"
APEX_EDITOR="Godot_v$APEX_GODOT_VERSION-stable_linux.x86_64"
APEX_TEMPLATES="Godot_v$APEX_GODOT_VERSION-stable_export_templates.tpz"
if [[ $(uname -m) != x86_64 ]]; then
  echo 'El builder requiere linux/amd64. Usa Compose o docker build --platform linux/amd64.' >&2
  exit 1
fi
mkdir -p "$APEX_DOWNLOADS" "$APEX_PREFIX/bin" "$APEX_PREFIX/export_templates/$APEX_GODOT_VERSION.stable"
download_verified() {
  local name=$1 expected=$2 archive="$APEX_DOWNLOADS/$1"
  if [[ ! -f $archive ]]; then
    curl --fail --location --retry 3 --connect-timeout 30 \
      "$APEX_REMOTE/$name" --output "$archive.part"
    mv -- "$archive.part" "$archive"
  fi
  if ! printf '%s  %s\n' "$expected" "$archive" | sha512sum --check --status; then
    rm -f -- "$archive"
    echo "SHA-512 incorrecto: $name. Se descarto la copia corrupta; vuelve a compilar." >&2
    exit 1
  fi
}
download_verified "$APEX_EDITOR.zip" "$APEX_EDITOR_SHA512"
download_verified "$APEX_TEMPLATES" "$APEX_TEMPLATES_SHA512"
unzip -p "$APEX_DOWNLOADS/$APEX_EDITOR.zip" "$APEX_EDITOR" > "$APEX_PREFIX/bin/godot"
chmod 755 "$APEX_PREFIX/bin/godot"
APEX_TEMPLATE_DIR="$APEX_PREFIX/export_templates/$APEX_GODOT_VERSION.stable"
unzip -oj "$APEX_DOWNLOADS/$APEX_TEMPLATES" \
  templates/linux_release.x86_64 templates/windows_release_x86_64.exe \
  templates/windows_release_x86_64_console.exe templates/web_nothreads_release.zip \
  templates/version.txt -d "$APEX_TEMPLATE_DIR"
chmod 755 "$APEX_TEMPLATE_DIR/linux_release.x86_64"
[[ $(cat "$APEX_TEMPLATE_DIR/version.txt") == "$APEX_GODOT_VERSION.stable" ]]
cp -- "$APEX_SCRIPT_DIR/godot.lock" "$APEX_PREFIX/godot.lock"
"$APEX_PREFIX/bin/godot" --headless --version
