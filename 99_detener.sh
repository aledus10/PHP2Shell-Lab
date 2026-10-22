#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v docker >/dev/null 2>&1; then
  echo '[ERROR] No se encuentra Docker.' >&2
  exit 1
fi
if docker compose version >/dev/null 2>&1; then
  docker compose down --remove-orphans
fi
# Funciona también si se arrancó con docker run, sin Compose.
for name in php2shell-linkedin-109618 php2shell-linkedin-109619; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    docker rm -f "$name"
  fi
done
printf '\n[OK] Contenedores del laboratorio detenidos y eliminados. Imágenes conservadas.\n'
