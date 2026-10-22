# Publicación sugerida para LinkedIn

🚨 **PHP2Shell: dos vulnerabilidades críticas en el núcleo de PHP (CVSS 9,2)**

El 21 de octubre se divulgaron **CVE-2026-109618** y **CVE-2026-109619**, dos fallos que pueden terminar en ejecución remota de código sin autenticación bajo determinadas condiciones.

Lo interesante es que no hablamos de una SQLi ni de un `eval()` expuesto en una web. Hablamos del propio **motor de PHP**:

🔹 **CVE-2026-109618:** un error *Out of Memory* puede interrumpir la inicialización de una petición, dejando estructuras internas en un estado inválido que se utiliza durante la limpieza.

🔹 **CVE-2026-109619:** una referencia global puede sobrevivir a la memoria de su petición. Si otra petición reutiliza el worker y consume ese estado, puede aparecer un *use-after-free*.

He preparado un **paper y un laboratorio educativo con dos Docker** para quien quiera estudiar estos conceptos paso a paso: parámetros como `memory_limit` y `post_max_size`, procesamiento multipart, reutilización de workers, y cómo se traduce el impacto de una hipotética RCE a las operaciones que podría hacer el proceso web.

📦 Incluye Dockerfiles, arranque automático (con o sin Docker Compose), una guía TXT y comandos reproducibles. Los laboratorios se ejecutan **solo en localhost**.

**Transparencia técnica:** la parte de impacto es una demostración controlada con acciones predefinidas; no es un exploit de estas CVE ni debe presentarse como tal.

✅ Versiones corregidas: **PHP 8.2.35 / 8.3.36 / 8.4.27 / 8.5.12**. Actualizar es esencial.

🔗 **Descarga del laboratorio:** [AÑADIR ENLACE A TU REPOSITORIO O RELEASE DE GITHUB]
📄 **Paper:** [ADJUNTAR PDF A LA PUBLICACIÓN]

¿Habíais revisado la versión de PHP y el SAPI utilizado en vuestras aplicaciones?

#CyberSecurity #PHP #VulnerabilityResearch #AppSec #Docker #CVE #Pentesting #BlueTeam
