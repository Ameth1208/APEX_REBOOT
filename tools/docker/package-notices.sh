#!/usr/bin/env bash
set -euo pipefail
APEX_PROJECT=$1
APEX_OUTPUT=$2
APEX_TARGET=$3
APEX_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$APEX_OUTPUT/assets/vehicles"
cp -- "$APEX_PROJECT/README_ES.md" "$APEX_OUTPUT/"
cp -R -- "$APEX_PROJECT/docs" "$APEX_PROJECT/licenses" "$APEX_OUTPUT/"
cp -- "$APEX_PROJECT/assets/vehicles/THIRD_PARTY_NOTICES.md" "$APEX_OUTPUT/assets/vehicles/"
mkdir -p "$APEX_OUTPUT/assets/rider/quaternius"
cp -- "$APEX_PROJECT/assets/rider/THIRD_PARTY_NOTICES.md" "$APEX_OUTPUT/assets/rider/"
for APEX_NOTICE in License_Standard.txt CC0-1.0.txt source-audit.json; do
  cp -- "$APEX_PROJECT/assets/rider/quaternius/$APEX_NOTICE" "$APEX_OUTPUT/assets/rider/quaternius/"
done
mkdir -p "$APEX_OUTPUT/assets/fonts/barlow"
for APEX_NOTICE in OFL.txt source-audit.json; do
  cp -- "$APEX_PROJECT/assets/fonts/barlow/$APEX_NOTICE" "$APEX_OUTPUT/assets/fonts/barlow/"
done
case "$APEX_TARGET" in
  Linux)
    cp -- "$APEX_SCRIPT_DIR/launchers/INICIAR_LINUX.sh" "$APEX_OUTPUT/"
    chmod +x "$APEX_OUTPUT/INICIAR_LINUX.sh"
    ;;
  Windows) cp -- "$APEX_SCRIPT_DIR/launchers/INICIAR_WINDOWS.bat" "$APEX_OUTPUT/" ;;
  Web) cp -- "$APEX_SCRIPT_DIR/launchers/SERVIR_WEB.py" "$APEX_SCRIPT_DIR/launchers/LEEME_WEB.txt" "$APEX_OUTPUT/" ;;
esac
