# PHP2Shell - laboratorio educativo para LinkedIn

**Dos CVE reales. Dos contenedores Docker. Observación reproducible y una emulación de impacto claramente identificada.**

Fecha de revisión: **22 de octubre de 2026**. Autor del proyecto educativo: **Alejandro Aránguez Romera**.

## ¿Qué contiene?

| Servicio | Versión / SAPI | Acceso | Objetivo |
| --- | --- | --- | --- |
| `cve-109618` | PHP **8.3.35**, Apache mod_php | `http://127.0.0.1:18118/` | Observar directivas y el procesamiento multipart normal |
| `cve-109619` | PHP **8.3.35**, Apache mod_php, worker único | `http://127.0.0.1:18119/` | Observar reutilización de worker y consecuencias de RCE **emuladas** |

**Advertencia fundamental:** las dos imágenes son vulnerables *por versión* según los avisos oficiales; los scripts de observación NO explotan las CVE. El endpoint `impacto_controlado.php` contiene expresamente una lista cerrada de operaciones y **no** es un exploit. No afirmar que esta demo acredita RCE mediante ninguna CVE. La demostración de acciones reales en el contenedor sirve para explicar el impacto potencial si un atacante obtuviera ejecución.

## Requisitos

- Docker Engine (Docker Compose V2 es **opcional**: los scripts usan Docker CLI si no está instalado)
- `curl` y `python3` para las pruebas CLI
- Puertos `18118` y `18119` libres

## Inicio rápido

```bash
unzip PHP2Shell_LinkedIn_Lab.zip
cd PHP2Shell_LinkedIn_Lab
./00_iniciar.sh
./01_probar_paso_a_paso.sh
```

Si los scripts no son ejecutables: `bash 00_iniciar.sh` y `bash 01_probar_paso_a_paso.sh`.

Abrir en el navegador: `http://127.0.0.1:18118/` y `http://127.0.0.1:18119/`.

**Parada:** `./99_detener.sh` (solo afecta a los contenedores de este laboratorio).

## Comandos destacados

### CVE-2026-109618: observar parámetros y multipart

```bash
curl -sS http://127.0.0.1:18118/inspeccionar.php | python3 -m json.tool
curl -sS -F 'usuario=alumno' -F 'tema=PHP2Shell' http://127.0.0.1:18118/inspeccionar.php | python3 -m json.tool
```

Fíjate en `directivas.memory_limit`, `post_max_size`, `max_input_nesting_level`, `max_file_uploads` y `peticion.campos_post_recibidos`. Es una petición multipart **normal**; no usa un payload OOM.

### CVE-2026-109619: ciclo de vida de los workers

```bash
for i in 1 2 3; do curl -sS http://127.0.0.1:18119/inspeccionar.php | python3 -c 'import json,sys; print(json.load(sys.stdin)["worker_pid"])'; done
```

Las peticiones ordinarias muestran el mismo `worker_pid` porque Apache tiene un único proceso hijo. **Eso no demuestra una UAF.** Solo evidencia un requisito de la clase de fallo: el worker sobrevive entre peticiones.

### Impacto emulado: qué pasaría si un atacante tuviera RCE

```bash
curl -sS 'http://127.0.0.1:18119/impacto_controlado.php?accion=identidad' | python3 -m json.tool
curl -sS 'http://127.0.0.1:18119/impacto_controlado.php?accion=leer_demo' | python3 -m json.tool
curl -sS 'http://127.0.0.1:18119/impacto_controlado.php?accion=crear_marca' | python3 -m json.tool
docker exec php2shell-linkedin-109619 cat /tmp/php2shell_marca_educativa.txt
```

Las acciones se realizan realmente dentro del contenedor (identidad del usuario web, lectura de un archivo **ficticio**, escritura de una marca), pero el endpoint las permite a propósito. No hay shell interactiva, comandos arbitrarios ni explotación de las CVE.

## Parámetros e interpretación

| Parámetro | En los Docker | Por qué importa |
| --- | --- | --- |
| `memory_limit` | 128M | Presupuesto de memoria por petición gestionado por PHP; relevante en condiciones OOM. |
| `post_max_size` | 8M | Límite de POST que por sí solo no cubre todos los consumos internos multipart. |
| `upload_max_filesize` | 2M | Tamaño por archivo. No cubre la amplificación de estructuras internas. |
| `max_file_uploads` | 20 | Máximo de cargas reconocidas; no equivale a límite universal del trabajo de formularios. |
| `max_input_vars` | 1000 | Limita algunas variables de entrada procesadas. |
| `max_input_nesting_level` | 64 | Limita profundidad de variables de entrada. |
| `max_multipart_body_parts` | valor de versión | Consultar el valor efectivo; relevante para multipart. |
| `session.upload_progress.enabled` | 1 (On) | Funcionalidad relacionada con un productor/consumidor confirmado de estado obsoleto. |

**No cambies estos valores en producción como única defensa.** El parche es la única mitigación completa confirmada por el proyecto PHP.

## Alcance, limitaciones y seguridad

- Solo escucha en `127.0.0.1`, nunca publicar el contenedor en Internet. Los procesos corren como PHP/Apache del contenedor, no como root del anfitrión.
- Cada contenedor tiene un límite Docker de memoria de 256 MB para acotar el consumo; no se provoca intencionadamente OOM.
- Las páginas muestran PHP y SAPI reales desde Apache; `php -v` dentro del Docker corresponde al PHP CLI y no se utiliza como sustituto de la comprobación HTTP.
- La medida `memory_get_peak_usage()` procede del script, **después** de empezar a ejecutarse; no es el consumo completo de memoria del parser multipart.
- La demo **no produce crash, UAF, corrupción ni RCE por las CVE**. Por tanto, no compara el comportamiento explotable frente al parche.
- Un exploit real fiable depende del layout de heap, compilación, extensiones, modelo de proceso y configuración, según los avisos oficiales.

## Remediación oficial

Versiones corregidas: **PHP 8.2.35, 8.3.36, 8.4.27 y 8.5.12**. Otras ramas antiguas que no reciben soporte deben migrarse a una rama mantenida. Revisar también exposición de mod_php, input multipart y sesión, y reiniciar workers tras la actualización.

## Fuentes primarias

- CVE-2026-109618 - https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
- CVE-2026-109619 - https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
- https://www.php.net/supported-versions.php

## Estructura

```text
PHP2Shell_LinkedIn_Lab/
├── compose.yaml
├── 00_iniciar.sh
├── 01_probar_paso_a_paso.sh
├── 99_detener.sh
├── CVE-2026-109618/          # PHP 8.3.35 + observación multipart
├── CVE-2026-109619/          # PHP 8.3.35 + worker persistente + impacto emulado
├── GUIA_PASO_A_PASO.txt
├── PAPER_PHP2SHELL.md
├── PAPER_PHP2SHELL.pdf
└── POST_LINKEDIN.md
```

Las imágenes se construyen localmente desde los Dockerfiles; el ZIP no incluye capas de imagen Docker.

Si `docker compose version` falla en tu máquina, `./00_iniciar.sh` usa automáticamente `docker build` y `docker run`. El puerto sigue vinculado a `127.0.0.1` y `./99_detener.sh` limpia solo los dos contenedores de este laboratorio.
