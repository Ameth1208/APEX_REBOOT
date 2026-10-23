#!/usr/bin/env python3
"""Package existing Godot exports and source with Python 3.10+ standard library."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import zipfile

TARGETS = {
    "source": (None, "Fuente_Godot", {}),
    "windows": ("Windows", "Windows_x64", {"APEX_REBOOT.exe": b"MZ", "APEX_REBOOT.pck": b"GDPC"}),
    "linux": ("Linux", "Linux_x64", {"APEX_REBOOT.x86_64": b"\x7fELF", "APEX_REBOOT.pck": b"GDPC"}),
    "web": ("Web", "Web", {"index.html": None, "index.js": None, "index.wasm": b"\x00asm", "index.pck": b"GDPC"}),
}
SKIP_DIRS = {".git", ".godot", "build", "dist", ".tools", ".cache", "__pycache__",
             ".pytest_cache", ".mypy_cache", ".ruff_cache", "node_modules"}
SKIP_NAMES = {".DS_Store", "Thumbs.db", ".env"}
KEEP_DOTFILES = {".dockerignore", ".gitignore", ".gitattributes", ".editorconfig", ".gdignore"}
SKIP_SUFFIXES = {".tmp", ".pyc", ".pyo", ".log", ".part"}
NOTICES = (
    "assets/vehicles/THIRD_PARTY_NOTICES.md",
    "assets/rider/THIRD_PARTY_NOTICES.md",
    "assets/rider/quaternius/License_Standard.txt",
    "assets/rider/quaternius/CC0-1.0.txt",
    "assets/rider/quaternius/source-audit.json",
    "assets/fonts/barlow/OFL.txt",
    "assets/fonts/barlow/source-audit.json",
)
SOURCE_REQUIRED = ("project.godot", "export_presets.cfg", "Dockerfile", "compose.yaml",
                   ".dockerignore", ".gitignore", ".editorconfig", ".github/workflows/build.yml")
LAUNCHERS = {"windows": "INICIAR_WINDOWS.bat", "linux": "INICIAR_LINUX.sh", "web": "SERVIR_WEB.py"}


def collect(folder: Path, excluded: set[Path] | None = None) -> dict[str, Path]:
    """Include useful dotfiles explicitly; prune caches before descending."""
    files = {}
    excluded = excluded or set()
    for base, dirs, names in os.walk(folder, onerror=raise_walk_error):
        parent = Path(base)
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and parent / d not in excluded)
        for directory in dirs:
            if (parent / directory).is_symlink():
                raise ValueError(f"No se empaquetan enlaces simbólicos: {parent / directory}")
        for name in sorted(names):
            path = parent / name
            if name in SKIP_NAMES or path.suffix in SKIP_SUFFIXES or name.startswith(".env."):
                continue
            if name.startswith(".") and name not in KEEP_DOTFILES:
                continue
            if path.is_symlink():
                raise ValueError(f"No se empaquetan enlaces simbólicos: {path}")
            files[path.relative_to(folder).as_posix()] = path
    return files


def raise_walk_error(error: OSError) -> None:
    raise error


def require(files: dict[str, Path], names) -> None:
    for name in names:
        if name not in files or not files[name].is_file() or files[name].stat().st_size == 0:
            raise ValueError(f"Falta un archivo requerido o está vacío: {name}")


def documentation(project: Path) -> dict[str, Path]:
    files = {"README_ES.md": project / "README_ES.md"}
    for directory in ("docs", "licenses"):
        files.update({f"{directory}/{name}": path for name, path in collect(project / directory).items()})
    files.update({name: project / name for name in NOTICES})
    # Retain each supplied model's provenance alongside its third-party notice.
    for path in (project / "assets/vehicles").glob("*/source-audit.json"):
        files[path.relative_to(project).as_posix()] = path
    require(files, ("README_ES.md", "licenses/LICENSE.txt", "licenses/COPYRIGHT.txt", *NOTICES))
    if not any(name.startswith("docs/") for name in files):
        raise ValueError("Falta la documentación del proyecto.")
    return files


def inventory(project: Path, build: Path, output: Path, target: str) -> dict[str, Path]:
    folder, _, signatures = TARGETS[target]
    if target == "source":
        files = collect(project, {build, output})
        require(files, SOURCE_REQUIRED)
        for path in files.values():
            if path.suffix.lower() in {".glb", ".gltf", ".fbx", ".bin", ".png", ".jpg"} and path.stat().st_size < 1024:
                if path.read_bytes().startswith(b"version https://git-lfs.github.com/spec/v1"):
                    raise ValueError(f"Falta descargar el recurso Git LFS: {path}")
    else:
        files = collect(build / folder)
        files = {name: path for name, path in files.items() if not name.startswith(("docs/", "licenses/"))}
        require(files, (*signatures, "BUILD_INFO.txt"))
        for name, magic in signatures.items():
            if magic:
                with files[name].open("rb") as stream:
                    if stream.read(len(magic)) != magic:
                        raise ValueError(f"Cabecera de exportación incorrecta: {files[name]}")
        launcher = LAUNCHERS[target]
        files[launcher] = project / "tools/docker/launchers" / launcher
        require(files, (launcher,))
        if target == "web":
            files["LEEME_WEB.txt"] = project / "tools/docker/launchers/LEEME_WEB.txt"
            require(files, ("LEEME_WEB.txt",))
    # Always use current notices/docs, even when the exports predate a doc edit.
    files.update(documentation(project))
    return dict(sorted(files.items()))


def write_archive(destination: Path, files: dict[str, Path], target: str) -> str:
    temporary = destination.with_suffix(".zip.part")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=True) as archive:
            for name, path in files.items():
                info = zipfile.ZipInfo.from_file(path, f"{destination.stem}/{name}", strict_timestamps=False)
                mode = stat.S_IMODE(path.stat().st_mode)
                if target == "linux" and name in {"APEX_REBOOT.x86_64", "INICIAR_LINUX.sh"}:
                    mode |= 0o111
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | mode) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                with path.open("rb") as source, archive.open(info, "w", force_zip64=info.file_size >= 2**31) as dest:
                    shutil.copyfileobj(source, dest, length=1024 * 1024)
        digest = hashlib.sha256()
        with temporary.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        temporary.replace(destination)
        return digest.hexdigest()
    finally:
        temporary.unlink(missing_ok=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--build-dir", type=Path, help="Default: PROJECT/build")
    parser.add_argument("--output-dir", type=Path, help="Default: BUILD/packages")
    parser.add_argument("--version", default="0.3.2")
    parser.add_argument("--target", choices=["all", *TARGETS], default="all")
    parser.add_argument("--dry-run", action="store_true", help="Validate/list inputs without writing archives")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing release ZIPs")
    args = parser.parse_args(argv)
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,31}", args.version):
        parser.error("La versión sólo puede contener letras, números, puntos, guiones y guiones bajos.")
    project = args.project.resolve()
    build = (args.build_dir or project / "build").resolve()
    output = (args.output_dir or build / "packages").resolve()
    if output == project or build == project:
        parser.error("Las carpetas build y de salida deben ser distintas de la raíz del proyecto.")
    selected = list(TARGETS) if args.target == "all" else [args.target]
    try:
        # Validate every target before opening the first output file.
        plans = []
        for target in selected:
            path = output / f"APEX_REBOOT_v{args.version}_{TARGETS[target][1]}.zip"
            if path.exists() and not args.overwrite and not args.dry_run:
                raise ValueError(f"Ya existe {path}; utiliza --overwrite para sustituirlo.")
            files = inventory(project, build, output, target)
            size = sum(p.stat().st_size for p in files.values())
            print(f"{path.name}: {len(files)} archivos, {size / 1024**2:.1f} MiB antes de comprimir", flush=True)
            plans.append((target, path, files))
        if args.dry_run:
            print("Validación terminada; no se ha creado ningún ZIP.")
            return 0
        output.mkdir(parents=True, exist_ok=True)
        sums = []
        for target, path, files in plans:
            checksum = write_archive(path, files, target)
            sums.append(f"{checksum}  {path.name}\n")
            print(f"Creado: {path} ({path.stat().st_size / 1024**2:.1f} MiB)", flush=True)
        checksum_file = output / "SHA256SUMS.txt"
        temporary = checksum_file.with_suffix(".txt.part")
        temporary.write_text("".join(sums), encoding="utf-8")
        temporary.replace(checksum_file)
        return 0
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"No se pudo empaquetar: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
