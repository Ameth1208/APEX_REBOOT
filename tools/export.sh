#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APEX_VERSION="4.6.3"
APEX_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/apex-reboot-build"
APEX_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$APEX_VERSION.stable"
mkdir -p "$APEX_CACHE" "$APEX_DATA" build/Windows build/Linux build/Web
touch build/.gdignore
APEX_REMOTE="https://github.com/godotengine/godot/releases/download/$APEX_VERSION-stable"
download() {
  local filename="$1"
  if [ ! -f "$APEX_CACHE/$filename" ]; then
    curl --fail --location --retry 2 "$APEX_REMOTE/$filename" -o "$APEX_CACHE/$filename.part"
    mv "$APEX_CACHE/$filename.part" "$APEX_CACHE/$filename"
  fi
}
verify() {
  local filename="$1"
  (cd "$APEX_CACHE"; awk -v f="$filename" '$2 == f {print}' SHA512-SUMS.txt | sha512sum --check --status)
}
if [ "$(uname -m)" != "x86_64" ]; then
  echo "Este asistente automático es para Linux x86_64. Abre project.godot con Godot 4.6.3 en otra arquitectura."
  exit 1
fi
command -v curl >/dev/null || { echo "Instala curl y vuelve a ejecutar."; exit 1; }
command -v unzip >/dev/null || { echo "Instala unzip y vuelve a ejecutar."; exit 1; }
command -v sha512sum >/dev/null || { echo "Instala coreutils (sha512sum) y vuelve a ejecutar."; exit 1; }
command -v awk >/dev/null || { echo "Instala awk y vuelve a ejecutar."; exit 1; }
download "SHA512-SUMS.txt"
APEX_ENGINE="Godot_v$APEX_VERSION-stable_linux.x86_64"
if [ ! -x "$APEX_CACHE/$APEX_ENGINE" ]; then
  download "$APEX_ENGINE.zip"
  verify "$APEX_ENGINE.zip"
  unzip -oq "$APEX_CACHE/$APEX_ENGINE.zip" -d "$APEX_CACHE"
  chmod +x "$APEX_CACHE/$APEX_ENGINE"
fi
if [ ! -f "$APEX_DATA/windows_release_x86_64.exe" ] || [ ! -f "$APEX_DATA/linux_release.x86_64" ] || { [ "${1:-}" = "--web" ] && [ ! -f "$APEX_DATA/web_nothreads_release.zip" ]; }; then
  echo "Descarga inicial de plantillas oficiales (~1.2 GB); se reutilizarán en las siguientes compilaciones."
  APEX_TEMPLATES="Godot_v$APEX_VERSION-stable_export_templates.tpz"
  download "$APEX_TEMPLATES"
  verify "$APEX_TEMPLATES"
  unzip -oj "$APEX_CACHE/$APEX_TEMPLATES" 'templates/windows_*x86_64.exe' 'templates/linux_*x86_64' 'templates/web_nothreads*.zip' 'templates/version.txt' -d "$APEX_DATA"
fi
"$APEX_CACHE/$APEX_ENGINE" --headless --editor --path . --import
"$APEX_CACHE/$APEX_ENGINE" --headless --path . --export-release "Windows Desktop"
"$APEX_CACHE/$APEX_ENGINE" --headless --path . --export-release Linux
if [ "${1:-}" = "--web" ]; then
  "$APEX_CACHE/$APEX_ENGINE" --headless --path . --export-release Web
fi
for APEX_PLATFORM in Windows Linux Web; do
  [ "$APEX_PLATFORM" != Web ] || [ "${1:-}" = "--web" ] || continue
  mkdir -p "build/$APEX_PLATFORM/assets/vehicles"
  cp README_ES.md "build/$APEX_PLATFORM/"
  cp -R docs licenses "build/$APEX_PLATFORM/"
  cp assets/vehicles/THIRD_PARTY_NOTICES.md "build/$APEX_PLATFORM/assets/vehicles/"
done
echo "Exportaciones listas en build/Windows y build/Linux."
