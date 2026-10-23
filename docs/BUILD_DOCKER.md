# Compilar y empaquetar APEX REBOOT 0.3.1

Desde la carpeta que contiene `project.godot` y `compose.yaml`:

```sh
docker compose run --rm build
```

Ese comando prepara la imagen si falta, importa el proyecto y exporta los tres destinos. Docker se utiliza para construir los archivos; el juego se ejecuta después en Windows, Linux o el navegador, sin Docker. No hace falta instalar Godot en el ordenador para utilizar este flujo.

## Requisitos y primer uso

Usa Docker Engine con el complemento Compose en Linux, o Docker Desktop con **contenedores Linux** en Windows/macOS. Comprueba que `docker compose version` y `docker info` funcionan antes de compilar. La imagen utiliza BuildKit y un volumen de caché. La referencia del comando es [Docker Compose run](https://docs.docker.com/reference/cli/docker/compose/run/).

En Linux, el lanzador utiliza tus UID/GID para que los archivos generados te pertenezcan:

```sh
./tools/docker/build.sh
```

Su equivalente explícito es:

```sh
APEX_UID="$(id -u)" APEX_GID="$(id -g)" docker compose run --rm build
```

El comando corto de Compose usa `1000:1000`, habitual en un escritorio Linux. Si tu usuario tiene otro identificador, utiliza el lanzador. El motor se ejecuta como usuario sin privilegios. No hace falta cambiar los permisos de todos los archivos a `777`.

En PowerShell puedes usar directamente el comando de Compose o este lanzador:

```powershell
.\tools\docker\build.ps1
```

Los lanzadores comprueban que Docker/Compose y el daemon estén disponibles. Mantén los scripts `.sh` con saltos de línea LF si los editas en Windows.

También están los accesos de la raíz `./COMPILAR_DOCKER.sh` y `COMPILAR_DOCKER.bat`, que delegan en esos mismos lanzadores. El `.bat` admite `-Target web`, `-Target linux` o `-Target windows`; sin argumentos compila los tres destinos.

### Elegir un destino

```sh
docker compose run --rm build windows
docker compose run --rm build linux
docker compose run --rm build web
```

`all` es el valor predeterminado. El lanzador Linux acepta los mismos argumentos; el de PowerShell acepta, por ejemplo, `-Target web`.

## Archivos resultantes

| Carpeta | Archivo principal | Cómo ejecutarlo |
| --- | --- | --- |
| `build/Windows/` | `APEX_REBOOT.exe` y `APEX_REBOOT.pck` | Abrir el EXE o `INICIAR_WINDOWS.bat` |
| `build/Linux/` | `APEX_REBOOT.x86_64` y `APEX_REBOOT.pck` | Ejecutar `./INICIAR_LINUX.sh`; el binario queda marcado como ejecutable |
| `build/Web/` | `index.html`, `index.js`, `index.wasm`, `index.pck` y archivos auxiliares | Servir la carpeta por HTTP |
| `build/logs/` | Registro de importación y registro de cada exportación | Consultar si una etapa falla |

Conserva juntos los archivos de cada carpeta; el PCK contiene los recursos del juego. Cada destino recibe `README_ES.md`, `docs/`, las licencias de Godot, los avisos de los vehículos, los avisos/licencias del piloto y la licencia OFL de la tipografía Barlow Semi Condensed del HUD. `BUILD_INFO.txt` identifica la versión del motor y los SHA-512 fijados de los archivos oficiales.

Para probar la versión Web, instala Python 3 en tu ordenador y ejecuta:

```sh
python3 build/Web/SERVIR_WEB.py
```

En Windows puede utilizarse `py -3 build\Web\SERVIR_WEB.py`. Abre `http://127.0.0.1:8765/index.html`. El servidor se limita al ordenador local y se cierra con Ctrl+C. La exportación Web debe servirse por HTTP; abrir el HTML con `file://` no es equivalente. Véase [exportación Web de Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

## Primera descarga y cachés

La primera preparación descarga aproximadamente **1,33 GB** de archivos oficiales: unos 72 MB de editor Linux y 1.256 MB del paquete de plantillas. También se descargan la base de la imagen y las herramientas de extracción. El paquete de Godot contiene más plataformas, pero la imagen final conserva sólo el editor y las plantillas release necesarias para Linux x86_64, Windows x86_64 y Web sin hilos.

| Elemento | Dónde se conserva | Qué evita repetir |
| --- | --- | --- |
| Editor y plantillas extraídos | Capas de la imagen Docker | Instalar Godot en cada compilación |
| ZIP/TPZ descargados | Caché BuildKit `apex-godot-4.6.3` | Descargar de nuevo al reconstruir una capa posterior |
| Recursos importados del proyecto | `.godot/` dentro del proyecto montado | Reimportar los modelos y texturas que no cambiaron |
| Ajustes y caché auxiliar del editor | Volumen Compose `build-cache`, separado por UID | Perder ajustes temporales al eliminar el contenedor |
| Ejecutables y recursos exportados | `build/` en el ordenador | Copiarlos manualmente desde un contenedor |

`--rm` elimina el contenedor terminado, pero conserva la imagen, el volumen y los archivos del proyecto. El proyecto se monta directamente en `/workspace`, así que un cambio de GDScript, JSON, escena o modelo se utiliza en la siguiente ejecución. No exige reconstruir la imagen. Los modelos grandes quedan fuera del contexto de Docker gracias a la lista explícita de `.dockerignore`. Las reglas de caché y contexto se describen en [Docker: optimizar caché](https://docs.docker.com/build/cache/optimize/) y [contexto de compilación](https://docs.docker.com/build/concepts/context/).

La primera importación de este proyecto puede tardar varios minutos, especialmente por el Porsche. Docker no elimina el trabajo de convertir sus mallas y texturas. Cierra el editor Godot mientras este proceso use la misma carpeta `.godot/`; evita dos importaciones simultáneas sobre el mismo proyecto. El montaje tiene escritura porque Godot también genera archivos de importación y UID junto a los recursos.

Para reconstruir las herramientas después de cambiar `Dockerfile`, el instalador o `godot.lock`:

```sh
docker compose build build
docker compose run --rm build
```

No borres la imagen ni la caché en cada uso. Conservarlas es lo que hace más rápidas las siguientes compilaciones.

## Versión fijada y controles de error

La base `debian:bookworm-slim` está fijada por digest en `Dockerfile`. El archivo `tools/docker/godot.lock` fija **Godot 4.6.3 estable** y los SHA-512 oficiales del editor y las plantillas. El instalador verifica ambos archivos completos antes de extraerlos. Si una copia falla, la descarta y sale con error para que el siguiente intento vuelva a descargarla.

Fuentes de los archivos fijados:

- [Editor oficial Linux x86_64](https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip).
- [Plantillas oficiales de exportación](https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz).
- [Lista oficial SHA512-SUMS.txt](https://github.com/godotengine/godot/releases/download/4.6.3-stable/SHA512-SUMS.txt).

El exportador comprueba la versión del motor, utiliza `--headless --import` y `--export-release`, y detiene el proceso tanto ante una salida distinta de cero como ante `ERROR:` o `SCRIPT ERROR:` en el registro. Verifica además la presencia de los archivos principales. Los nombres de los destinos coinciden con `export_presets.cfg`; véase [línea de comandos de Godot](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#exporting).

La imagen final ejecuta `godot --headless --version` durante su construcción, como usuario sin privilegios, para comprobar que el motor puede arrancar en esa base antes de exportar. El ELF oficial revisado con `ldd` enlaza dinámicamente sólo componentes de glibc; no requiere `libstdc++` ni `libgcc` compartidas. Esta comprobación local no sustituye la ejecución de la imagen en Docker.

Aquí «reproducible» significa herramientas, versión, plantillas y comandos fijados. No se afirma que dos exportaciones produzcan ZIP o PCK idénticos byte a byte: metadatos y recursos del proyecto también pueden cambiar. Este flujo exporta usando plantillas oficiales; no compila el código C++ del motor ni utiliza Rust.

## Ejecutar el mismo exportador sin Docker

En Linux x86_64 también se puede utilizar exactamente `tools/docker/export.sh` con una instalación local de los archivos oficiales. El instalador requiere Bash, curl, unzip y sha512sum; conserva las mismas comprobaciones del lock:

```bash
APEX_TOOLCHAIN="$PWD/.tools/godot"
bash tools/docker/install-godot.sh "$APEX_TOOLCHAIN" "$PWD/.tools/downloads"
APEX_GODOT_BIN="$APEX_TOOLCHAIN/bin/godot" \
APEX_TEMPLATE_ROOT="$APEX_TOOLCHAIN/export_templates" \
APEX_CACHE_ROOT="$PWD/.tools/cache" \
bash tools/docker/export.sh all
```

Si ya tienes esa instalación oficial, ejecuta únicamente el segundo comando con sus rutas. `APEX_PROJECT_DIR` y `APEX_OUTPUT_DIR` permiten cambiar las carpetas de proyecto y salida. Las variables XDG se preparan dentro del exportador para que el editor encuentre las plantillas. Este flujo comparte el importador, los presets y los controles de error con el contenedor; no comprueba el arranque de Docker ni sus montajes.

## Crear los cuatro ZIP de entrega

Después de exportar, `tools/package-release.py` requiere Python 3.10 o posterior y sólo utiliza su biblioteca estándar. Puedes revisar las entradas sin escribir archivos:

```bash
python3 tools/package-release.py --dry-run
python3 tools/package-release.py
```

El primer comando valida el contenido de las cuatro entregas; el segundo crea los ZIP. Cada uno contiene una carpeta superior con el mismo nombre del archivo comprimido:

| Archivo en `build/packages/` | Contenido |
| --- | --- |
| `APEX_REBOOT_v0.3.1_Fuente_Godot.zip` | Proyecto editable, modelos, scripts, pruebas, Docker y workflow. |
| `APEX_REBOOT_v0.3.1_Windows_x64.zip` | EXE, PCK, lanzador, documentación y avisos. |
| `APEX_REBOOT_v0.3.1_Linux_x64.zip` | Ejecutable, PCK, lanzador, documentación y avisos. |
| `APEX_REBOOT_v0.3.1_Web.zip` | HTML/JS/WASM/PCK, servidor local, documentación y avisos. |
| `SHA256SUMS.txt` | SHA-256 de los ZIP creados en esa ejecución. |

El paquete fuente incluye `.github/`, `.dockerignore`, `.gitignore` y `.editorconfig`. Excluye `.godot/`, `build/`, metadatos Git, cachés y archivos temporales. Comprueba que los modelos no sean simples punteros de Git LFS pendientes de descargar. El empaquetado conserva los permisos UNIX de los archivos y marca como ejecutables el binario y lanzador Linux. Esa información depende también del programa usado para extraer el ZIP; si se pierde, utiliza el `chmod` descrito en el README. La API utilizada es [ZipFile y ZipInfo de Python](https://docs.python.org/3.12/library/zipfile.html).

Las entregas compiladas incorporan los documentos y avisos actuales del fuente aunque se hayan editado después de exportar. No hace falta reexportar un PCK por una corrección exclusivamente documental. Sí debes reexportar después de cambiar scripts, escenas, modelos o datos del juego. El empaquetador no modifica las carpetas de exportación.

Opciones útiles: `--target source`, `--target windows`, `--target linux`, `--target web`, `--build-dir RUTA`, `--output-dir RUTA` y `--version 0.3.1`. Por defecto se niega a sustituir un ZIP existente; utiliza `--overwrite` para generar de nuevo esa entrega. Antes de escribir valida todas las plataformas solicitadas, los archivos principales, sus cabeceras y `BUILD_INFO.txt`.

## Compilación manual en GitHub Actions

El archivo [`.github/workflows/build.yml`](../.github/workflows/build.yml) prepara un flujo que se inicia desde **Actions → Build and verify APEX REBOOT → Run workflow** cuando esté incorporado en la rama predeterminada del repositorio. Sólo declara `workflow_dispatch`: no se ejecuta al subir commits y no crea Releases ni despliega la versión Web. El comportamiento de inicio manual está documentado por [GitHub](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).

| Job | Trabajo que ejecutará |
| --- | --- |
| Ubuntu 24.04 x64 | Obtiene los recursos, construye la imagen fijada, exporta con Compose, ejecuta regresiones físicas/reglas/IA, arranca el Linux compilado y crea los cuatro paquetes. |
| Windows 2022 x64 | Descarga el mismo ZIP Windows, comprueba su SHA-256 y arranca su EXE/PCK en Windows, con límite de tiempo y revisión de registros. |

Los arranques usan `--headless --quit-after 120`. Comprueban carga y salida del juego compilado; no certifican renderizado, sonido de altavoces, mando ni todas las configuraciones de Windows/Linux. Esas opciones existen en las plantillas release de [Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html). Las etiquetas de los ejecutores están recogidas en la [referencia de GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

Se conservan artefactos y registros de esa ejecución durante 14 días, dentro de los permisos del repositorio. Los ZIP preparados se suben como archivos completos para conservar su estructura y metadatos internos. Las acciones oficiales están fijadas a commits de [checkout 7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1), [upload-artifact 7.0.0](https://github.com/actions/upload-artifact/releases/tag/v7.0.0) y [download-artifact 8.0.2](https://github.com/actions/download-artifact/releases/tag/v8.0.2). El workflow sólo solicita `contents: read` y no guarda las credenciales del checkout.

El repositorio deberá contener los modelos reales, incluidos los objetos Git LFS si los usas. Cada nuevo runner descarga/construye las herramientas: no se ha añadido una caché remota entre ejecuciones. Las cuotas de minutos, disco y artefactos dependen de la cuenta y del repositorio. Este archivo define una compilación ejecutable; **no se ha ejecutado GitHub Actions durante esta preparación**.

## Linux nativo, Docker Desktop y equipos ARM

En Linux x86_64, Docker Engine ejecuta contenedores Linux directamente. Un Godot instalado de forma nativa evita incluso esa capa y puede ser la opción más sencilla si ya tienes el editor y las plantillas; los scripts anteriores `tools/export.sh` y `tools/export.ps1` siguen disponibles. No se promete que Docker exporte más rápido: su ventaja aquí es fijar las herramientas y simplificar su instalación.

Docker Desktop utiliza un entorno Linux virtualizado. El arranque de esa máquina, su memoria y el intercambio de archivos con el sistema anfitrión añaden trabajo. En Windows, usar la integración WSL 2 y guardar el proyecto dentro del sistema de archivos de la distribución puede ayudar a reducir el coste del acceso a archivos frente a trabajar en una carpeta Windows montada. Consulta las [recomendaciones oficiales para WSL 2 y archivos montados](https://docs.docker.com/desktop/features/wsl/best-practices/) y las [opciones de la máquina virtual](https://docs.docker.com/desktop/features/vmm/). No se incluyen cifras comparativas porque no se midieron en esas plataformas.

La imagen está fijada a **`linux/amd64`**. En un anfitrión ARM, por ejemplo Apple Silicon, se necesita emulación AMD64 o un builder remoto AMD64. Compose ya declara la plataforma; si construyes manualmente utiliza `docker build --platform linux/amd64 .`. La emulación puede ralentizar importaciones, descompresión y exportación; [Docker documenta ese coste y sus alternativas](https://docs.docker.com/build/building/multi-platform/). Los ejecutables resultantes siguen siendo Windows/Linux x86_64, y la versión Web usa WebAssembly. No se generan ejecutables nativos ARM ni macOS en estos presets.

## Qué hacer si falla

| Mensaje o síntoma | Acción concreta |
| --- | --- |
| Docker o Compose no existe | Instalar Docker Engine + Compose o Docker Desktop y comprobar `docker compose version` |
| No hay conexión con el daemon | Iniciar Docker; en Windows comprobar que usa contenedores Linux |
| Sin permiso de escritura | En Linux ejecutar `tools/docker/build.sh` con el usuario propietario del proyecto |
| El hash de una descarga no coincide | Repetir la preparación; la copia incorrecta ya fue descartada |
| La versión no coincide con el lock | Ejecutar `docker compose build build` |
| Godot registra errores | Abrir `build/logs/import.log` o el registro del destino indicado; corregir el primer error |
| `exec format error` en ARM | Comprobar soporte de emulación AMD64 o utilizar un equipo/builder AMD64 |
| El navegador falla al abrir el HTML directamente | Iniciar `SERVIR_WEB.py` y abrir la dirección HTTP indicada |

La compilación conserva los avisos existentes de los modelos; no cambia sus licencias ni concede permisos adicionales de distribución.

## Validación de esta entrega

El entorno de preparación no dispone de un daemon Docker ni permite el aislamiento de usuarios necesario para iniciarlo. Por tanto **no se declara una ejecución satisfactoria de `docker compose run` en este entorno**. Las exportaciones locales se realizan mediante `tools/docker/export.sh` directamente, con el editor y las plantillas oficiales fijados en `godot.lock`. Los resultados del juego y de sus ejecutables se recogen en [VALIDATION.md](VALIDATION.md).

En esta revisión se comprobó la sintaxis Bash de los scripts de Docker y CI. Tres pruebas pequeñas del empaquetador aprobaron integridad CRC de los cuatro ZIP de prueba, documentos actuales, avisos, archivos de configuración, exclusión de cachés, permisos UNIX, operación `--dry-run` sin escritura y rechazo de un PCK incorrecto antes de crear archivos. Una lectura del fuente real con `--target source --dry-run` también terminó correctamente. Los ZIP pequeños son fixtures temporales; no sustituyen los paquetes finales ni una exportación del juego.

La revisión anterior de v0.2 dejó documentada la validación de `compose.yaml` con Compose 5.6.0, la verificación SHA-512 de las descargas, el rechazo de una copia corrupta y exportaciones completas fuera del contenedor, incluido un UID/GID sin privilegios. Son antecedentes del flujo conservado; no se presentan como una ejecución de Docker o CI de v0.3.

La construcción y arranque de la imagen, los montajes de Docker Desktop, la emulación ARM y el workflow remoto siguen pendientes de ejecución en sus entornos correspondientes. El workflow proporciona los comandos para comprobar Docker y el arranque nativo de Windows cuando se ejecute.
