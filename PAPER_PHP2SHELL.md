# PHP2Shell: dos fallos de memoria que convierten peticiones HTTP en riesgo de RCE

**Análisis técnico y laboratorio reproducible con Docker (versión divulgativa)**  
**22 de octubre de 2026 · Alejandro Aránguez Romera**

## Resumen

El 21 de octubre de 2026 se publicaron dos fallos críticos en el núcleo de PHP, **CVE-2026-109618** y **CVE-2026-109619** (CVSS v4.0 **9,2**, según los avisos del proyecto). El primero deriva de la gestión de errores de memoria al inicializar una petición. El segundo se origina en referencias globales que sobreviven al ciclo de vida de la memoria a la que apuntan. Ambos pueden dar lugar a ejecución remota de código (RCE) bajo las condiciones descritas por el mantenedor.

Esta publicación acompaña un laboratorio de **dos contenedores PHP 8.3.35 + Apache mod_php** que permite inspeccionar los límites configurados, observar peticiones multipart, verificar la reutilización de un worker e ilustrar *de manera emulada* las consecuencias de una RCE. **El laboratorio no contiene un exploit funcional ni demuestra que las CVE hayan sido explotadas.**

## 1. CVE-2026-109618: OOM, longjmp() y limpieza de memoria inválida

PHP empleaba `longjmp()` para abandonar el contexto actual ante determinados errores *out-of-memory* (OOM). Cuando una asignación fallaba con estructuras de petición parcialmente inicializadas, el salto podía eludir los pasos de restauración de estado correspondientes. El código de limpieza de la petición acababa accediendo a datos no válidos. El fallo podía producirse en el análisis automático de una petición HTTP, antes de que comenzara el código PHP de la aplicación.

Secuencia conceptual: `entrada HTTP -> análisis de multipart -> fallo de asignación -> longjmp() -> estado parcialmente inicializado -> limpieza sobre memoria inválida -> posible corrupción -> RCE (tras explotación especializada)`.

Los límites `memory_limit` y `post_max_size` son relevantes, pero no equivalentes. Los datos multipart pueden requerir más memoria en las estructuras internas que la que ocupan en el cuerpo HTTP. También importan `max_file_uploads`, `max_input_vars`, `max_input_nesting_level` y el límite de partes multipart disponible en la versión instalada. El aviso oficial explica que ningún ajuste de límites sustituye al parche.

## 2. CVE-2026-109619: referencias obsoletas y use-after-free

Los workers de PHP pueden persistir tras completar una petición. Algunas estructuras globales de errores, sesiones, objetos y extensiones hacen referencia temporal a memoria que pertenece a una petición. Deben limpiarse o desvincularse **antes** de liberar esa memoria. Ante determinados errores o fases de limpieza, puede sobrevivir una referencia obsoleta. Una operación posterior, en el mismo worker y antes de la inicialización normal de la siguiente petición, puede usarla: *use-after-free* (UAF).

Cadena conceptual: `petición A / productor -> global apunta a memoria temporal -> petición A termina y libera memoria -> global no se limpia -> petición B en el mismo worker / consumidor -> uso de referencia obsoleta -> posible corrupción -> RCE (tras manipulación especializada del heap)`.

Los avisos citan rutas relacionadas con diagnóstico de configuración temprana y `session.upload_progress.enabled`. Que dos peticiones tengan el mismo PID demuestra reutilización de worker, **no** demuestra por sí solo un UAF.

## 3. ¿Por qué un fallo de memoria puede convertirse en RCE?

El motor de PHP está escrito mayoritariamente en código nativo. Si un atacante consigue que se utilicen punteros no inicializados, que se liberen estructuras erróneas o que se manipule memoria liberada, el proceso puede bloquearse o, bajo condiciones favorables y con explotación especializada, llegar a desviar su flujo de ejecución. En Apache `mod_php`, el código resultante se ejecutaría con la identidad y los permisos del worker web. Eso puede permitir lectura de datos accesibles para esa cuenta, cambios en ficheros escribibles o acciones sobre servicios a los que el servidor tenga acceso. **RCE no implica automáticamente privilegios de root ni escape del contenedor.**

El exploit confirmado por el proyecto PHP es complejo y depende del heap, los binarios, extensiones, configuración y flujo de peticiones. No debe inferirse explotación a partir de una versión vulnerable, una respuesta HTTP o una prueba de comandos de demostración.

## 4. Guía reproducible: dos contenedores

Ambos contenedores se basan en `php:8.3.35-apache` y se publican solo en la interfaz local: `127.0.0.1:18118` y `127.0.0.1:18119`. Están limitados a 256 MB de RAM en Docker y sus pruebas no intentan provocar agotamiento de memoria ni corrupción. El primero muestra entradas multipart seguras y directivas PHP. El segundo configura un worker hijo único para facilitar la observación de PIDs y ofrece un endpoint opcional de **impacto emulado** con acciones fijas.

```bash
unzip PHP2Shell_LinkedIn_Lab.zip
cd PHP2Shell_LinkedIn_Lab
./00_iniciar.sh
./01_probar_paso_a_paso.sh
```

Inspección manual:

```bash
curl -sS -F 'tema=PHP2Shell' http://127.0.0.1:18118/inspeccionar.php | python3 -m json.tool
for i in 1 2 3; do curl -sS http://127.0.0.1:18119/inspeccionar.php | python3 -c 'import json,sys; print(json.load(sys.stdin)["worker_pid"])'; done
```

Ejemplo separado para hablar del **impacto si existiera ejecución remota**:

```bash
curl -sS 'http://127.0.0.1:18119/impacto_controlado.php?accion=identidad' | python3 -m json.tool
curl -sS 'http://127.0.0.1:18119/impacto_controlado.php?accion=crear_marca' | python3 -m json.tool
```

Aquí PHP ejecuta un comando fijo y crea un archivo deliberadamente. No es una explotación de las CVE. La guía de cada paso y los resultados esperados figuran en `GUIA_PASO_A_PASO.txt`.

## 5. Mitigaciones

Actualizar inmediatamente a una versión corregida: **8.2.35, 8.3.36, 8.4.27 o 8.5.12** o a una posterior mantenida. Reiniciar workers. Revisar exposición y necesidad de multipart, límites efectivos del frontal y de PHP, estados de sesión y errores del ciclo de vida. Desactivar `session.upload_progress.enabled` si no se utiliza reduce rutas específicas de la CVE-2026-109619, pero **no reemplaza** la actualización.

El proyecto PHP señala que **actualizar es la única mitigación completa** de ambos problemas. No basta con variar `memory_limit`, confiar en WAF o suponer que una aplicación sin funciones peligrosas queda protegida: parte del riesgo aparece antes de ejecutar la aplicación.

## 6. Limitaciones del laboratorio y conclusiones

Estas prácticas muestran un **entorno de versión vulnerable**, el contexto técnico y un **impacto emulado**, pero **no** confirman OOM maliciosa, UAF, corrupción del heap ni RCE por las CVE. La puntuación y el impacto proceden de los avisos oficiales, no de una supuesta explotación de los contenedores. Esta distinción es indispensable para no presentar una simulación como prueba de compromiso.

Conclusión: PHP2Shell pone de relieve que los límites de recursos, las rutas de error y la reutilización de procesos en el runtime importan tanto como el código de la aplicación. Inventariar PHP por **versión y SAPI**, actualizar y auditar configuraciones es prioritario.

## Fuentes

1. PHP Security Advisory, CVE-2026-109618: https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
2. PHP Security Advisory, CVE-2026-109619: https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
3. PHP supported versions: https://www.php.net/supported-versions.php
