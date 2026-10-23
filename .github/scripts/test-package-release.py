"""Tiny disposable fixtures verify packaging without exporting or shipping a game."""

import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location("apex_package", Path(__file__).resolve().parents[2] / "tools/package-release.py")
PACKAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGE)


class PackagingChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="apex_package_checks_")
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "source"
        self.project.mkdir()
        for name in (*PACKAGE.SOURCE_REQUIRED, *PACKAGE.NOTICES, "README_ES.md",
                     "docs/current.md", "licenses/LICENSE.txt", "licenses/COPYRIGHT.txt"):
            self.put(name, b"current fixture\n")
        for target, (folder, _, required) in PACKAGE.TARGETS.items():
            if folder is None:
                continue
            for name, magic in required.items():
                self.put(f"build/{folder}/{name}", (magic or b"text") + b" fixture\n")
            self.put(f"build/{folder}/BUILD_INFO.txt", b"Godot=4.6.3 fixture\n")
            self.put(f"tools/docker/launchers/{PACKAGE.LAUNCHERS[target]}", b"launcher fixture\n")
        self.put("build/Windows/README_ES.md", b"stale fixture\n")
        self.put("tools/docker/launchers/LEEME_WEB.txt", b"web instructions fixture\n")
        self.put("build/Windows/.APEX_REBOOT.pck.partial123", b"temporary export bytes\n")
        self.put("build/Windows/docs/deleted.md", b"stale fixture\n")
        for name in (".godot/imported/cache.bin", ".git/config", ".cache/cache.bin", "tools/__pycache__/cached.pyc"):
            self.put(name, b"local cache\n")
        self.put("tools/run.sh", b"#!/bin/sh\nexit 0\n").chmod(0o750)
        (self.project / "build/Linux/APEX_REBOOT.x86_64").chmod(0o644)

    def put(self, name, content):
        path = self.project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def run_package(self, *arguments):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return PACKAGE.main(["--project", str(self.project), *arguments])

    def test_four_archives_keep_source_metadata_and_current_notices(self):
        self.assertEqual(self.run_package(), 0)
        output = self.project / "build/packages"
        self.assertEqual(len(list(output.glob("*.zip"))), 4)
        for target, (_, suffix, _) in PACKAGE.TARGETS.items():
            stem = f"APEX_REBOOT_v0.3.1_{suffix}"
            with zipfile.ZipFile(output / f"{stem}.zip") as archive:
                self.assertIsNone(archive.testzip())
                names = {name.removeprefix(stem + "/") for name in archive.namelist()}
                for notice in PACKAGE.NOTICES:
                    self.assertIn(notice, names)
                self.assertEqual(archive.read(stem + "/README_ES.md"), b"current fixture\n")
                self.assertIn("docs/current.md", names)
                self.assertNotIn("docs/deleted.md", names)
                self.assertNotIn(".APEX_REBOOT.pck.partial123", names)
                if target == "web":
                    self.assertIn("LEEME_WEB.txt", names)
                if target == "source":
                    self.assertTrue(set(PACKAGE.SOURCE_REQUIRED) <= names)
                    self.assertFalse(any(set(Path(name).parts) & PACKAGE.SKIP_DIRS for name in names))
                    mode = archive.getinfo(stem + "/tools/run.sh").external_attr >> 16
                    self.assertEqual(mode & 0o777, 0o750)
                if target == "linux":
                    for executable in ("APEX_REBOOT.x86_64", "INICIAR_LINUX.sh"):
                        info = archive.getinfo(stem + "/" + executable)
                        self.assertEqual(info.create_system, 3)
                        self.assertEqual((info.external_attr >> 16) & 0o111, 0o111)
        self.assertEqual(len((output / "SHA256SUMS.txt").read_text().splitlines()), 4)

    def test_dry_run_writes_nothing(self):
        self.assertEqual(self.run_package("--dry-run"), 0)
        self.assertFalse((self.project / "build/packages").exists())

    def test_invalid_pck_stops_before_any_archive_is_written(self):
        self.put("build/Windows/APEX_REBOOT.pck", b"corrupt fixture")
        self.assertEqual(self.run_package(), 1)
        self.assertFalse((self.project / "build/packages").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
