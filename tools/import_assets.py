#!/usr/bin/env python3
"""Restore the four supplied models, preserving embedded materials and notices.

Only expected members are copied; archive paths are never extracted directly.
Godot 4.6 imports GLB and FBX itself. No Blender installation is required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zipfile
from pathlib import Path, PurePosixPath

ASSETS = {
    "yamaha_yzf_2021": ("yamaha-yzf-2021.zip", ".glb"),
    "porsche_992_gt3_rs_2024": ("porsche-992-gt3-rs-2024.zip", ".glb"),
    "ferrari_312t_1976": ("ferrari-312t-1976-wwwvecarzcom.zip", ".glb"),
    "senna_formula_1991": ("f1-ayrton-senna-1991-car.zip", ".fbx"),
}


def inspect_glb(payload: bytes) -> dict:
    if payload[:4] != b"glTF":
        raise ValueError("Invalid glTF binary header")
    length, kind = struct.unpack_from("<II", payload, 12)
    if kind != 0x4E4F534A:
        raise ValueError("The first GLB chunk must contain JSON")
    document = json.loads(payload[20 : 20 + length])
    triangles = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh["primitives"]:
            accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
            if primitive.get("mode", 4) == 4:
                triangles += document["accessors"][accessor]["count"] // 3
    return {
        "embedded_asset_metadata": document.get("asset", {}),
        "mesh_count": len(document.get("meshes", [])),
        "node_count": len(document.get("nodes", [])),
        "triangle_count": triangles,
        "material_names": [m.get("name", "") for m in document.get("materials", [])],
        "embedded_images": len(document.get("images", [])),
        "source_geometry_unchanged": True,
    }


def import_one(source: Path, target: Path, vehicle_id: str) -> dict:
    archive_name, extension = ASSETS[vehicle_id]
    archive_path = source / archive_name
    folder = target / vehicle_id
    folder.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        candidates = [n for n in archive.namelist() if n.lower().endswith(extension)]
        if len(candidates) != 1:
            raise ValueError(f"Expected one {extension} model in {archive_name}")
        member = candidates[0]
        info = archive.getinfo(member)
        if info.file_size > 512 * 1024 * 1024:
            raise ValueError("Unexpected model size; refusing to unpack")
        payload = archive.read(member)
        destination = folder / ("model" + extension)
        destination.write_bytes(payload)
        textures = []
        if extension == ".fbx":
            # The FBX references downloaded.fbm/*.jpg; the archive calls them *.jpeg.
            texture_folder = folder / "downloaded.fbm"
            texture_folder.mkdir(exist_ok=True)
            for name in archive.namelist():
                pure = PurePosixPath(name)
                if not name.startswith("textures/") or pure.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                    continue
                if archive.getinfo(name).file_size > 64 * 1024 * 1024:
                    raise ValueError(f"Unexpected texture size: {name}")
                basename = pure.stem + (".jpg" if pure.suffix.lower() == ".jpeg" else pure.suffix)
                (texture_folder / basename).write_bytes(archive.read(name))
                textures.append("downloaded.fbm/" + basename)
        notes = []
        for name in archive.namelist():
            pure = PurePosixPath(name)
            if pure.suffix.lower() in {".txt", ".md"} and any(x in pure.name.lower() for x in ("license", "readme", "copyright")):
                (folder / pure.name).write_bytes(archive.read(name))
                notes.append(pure.name)
    audit = {
        "source_archive": archive_name,
        "source_member": member,
        "sha256": hashlib.sha256(payload).hexdigest(),
        "source_bytes": len(payload),
        "copied_textures": textures,
        "copied_notices": notes,
    }
    if extension == ".glb":
        audit.update(inspect_glb(payload))
    else:
        audit["license_status"] = "No license grant was present in the supplied archive."
        audit["source_geometry_unchanged"] = True
    (folder / "source-audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return audit


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=project.parent / "upload")
    parser.add_argument("--target-dir", type=Path, default=project / "assets" / "vehicles")
    args = parser.parse_args()
    for vehicle_id in ASSETS:
        audit = import_one(args.source_dir, args.target_dir, vehicle_id)
        print(f"{vehicle_id}: {audit['source_bytes'] / 1048576:.1f} MiB imported")


if __name__ == "__main__":
    main()
