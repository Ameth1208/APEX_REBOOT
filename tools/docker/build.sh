#!/usr/bin/env bash
set -euo pipefail
APEX_PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$APEX_PROJECT_DIR"
command -v docker >/dev/null || { echo 'Instala Docker Engine + Compose o Docker Desktop.' >&2; exit 1; }
docker compose version >/dev/null
APEX_DOCKER_OS=$(docker info --format '{{.OSType}}')
[[ $APEX_DOCKER_OS == linux ]] || { echo 'Selecciona un Docker Engine de Linux o contenedores Linux en Docker Desktop.' >&2; exit 1; }
export APEX_UID=${APEX_UID:-$(id -u)}
export APEX_GID=${APEX_GID:-$(id -g)}
exec docker compose run --rm build "$@"
