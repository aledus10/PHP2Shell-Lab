#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo '[ERROR] Docker no está instalado o no está en PATH.' >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo '[ERROR] Docker Engine no responde. Comprueba: sudo systemctl start docker' >&2
  echo '        Y que tu usuario tenga permisos para ejecutar docker.' >&2
  exit 1
fi

NAME_618='php2shell-linkedin-109618'
NAME_619='php2shell-linkedin-109619'

if docker compose version >/dev/null 2>&1; then
  echo '[INFO] Docker Compose V2 detectado; construyendo y arrancando ambos laboratorios.'
  docker compose up -d --build
else
  echo '[INFO] Compose V2 no está disponible; utilizando Docker CLI directamente.'
  # Evitar sobrescribir o reutilizar contenedores ajenos/preexistentes.
  for name in "$NAME_618" "$NAME_619"; do
    if docker container inspect "$name" >/dev/null 2>&1; then
      echo "[ERROR] Ya existe $name. Para reiniciar: ./99_detener.sh && ./00_iniciar.sh" >&2
      exit 1
    fi
  done
  docker build -t php2shell-educativo:109618 ./CVE-2026-109618
  docker build -t php2shell-educativo:109619 ./CVE-2026-109619

  docker run -d --name "$NAME_618" \
    --memory 256m --security-opt no-new-privileges \
    -p 127.0.0.1:18118:80 \
    php2shell-educativo:109618 >/dev/null
  if ! docker run -d --name "$NAME_619" \
    --memory 256m --security-opt no-new-privileges \
    -p 127.0.0.1:18119:80 \
    php2shell-educativo:109619 >/dev/null; then
    docker rm -f "$NAME_618" >/dev/null 2>&1 || true
    echo '[ERROR] No pudo arrancar el segundo laboratorio. Se ha retirado el primero.' >&2
    exit 1
  fi
fi

printf '\n[OK] Laboratorios publicados SOLO en localhost:\n'
printf '  CVE-2026-109618 -> http://127.0.0.1:18118/\n'
printf '  CVE-2026-109619 -> http://127.0.0.1:18119/\n'
printf '\nEstado: docker ps --filter name=php2shell-linkedin-\n'
printf 'Parar y eliminar los contenedores del laboratorio: ./99_detener.sh\n'
