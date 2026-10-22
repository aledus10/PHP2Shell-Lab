#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v curl >/dev/null || { echo 'Instala curl'; exit 1; }
command -v python3 >/dev/null || { echo 'Instala python3'; exit 1; }
show() { printf '\n== %s ==\n' "$1"; }
show '1 - PHP 8.3.35 y parámetros de límites'
curl -fsS http://127.0.0.1:18118/inspeccionar.php | python3 -m json.tool
show '2 - Una petición multipart normal y segura'
curl -fsS -F 'usuario=alumno' -F 'tema=PHP2Shell' http://127.0.0.1:18118/inspeccionar.php | python3 -m json.tool
show '3 - Dos peticiones atendidas por un worker de Apache'
for x in 1 2; do
  printf 'peticion %s: ' "$x"
  curl -fsS http://127.0.0.1:18119/inspeccionar.php | python3 -c 'import json,sys; o=json.load(sys.stdin); print("worker_pid:",o["worker_pid"],"sapi:",o["sapi"])'
done
show '4 - Impacto demostrativo: identidad del proceso web'
curl -fsS 'http://127.0.0.1:18119/impacto_controlado.php?accion=identidad' | python3 -m json.tool
show '5 - Impacto demostrativo: escritura controlada'
curl -fsS 'http://127.0.0.1:18119/impacto_controlado.php?accion=crear_marca' | python3 -m json.tool
show '6 - Confirmación dentro de Docker'
docker exec php2shell-linkedin-109619 cat /tmp/php2shell_marca_educativa.txt
show 'FIN: ninguna de estas pruebas constituye explotación de las CVE'
