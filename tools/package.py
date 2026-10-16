"""Build the drag-and-drop release zip.

Produces dist/gridiron-v<version>.zip containing a single `gridiron/` folder
with only what the game loads (metadata, main.lua, content/, resources/).
Unzip it straight into the Isaac `mods` folder.

Usage (from the repo root):   python3 tools/package.py [--expect-version X.Y.Z]
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOD_FOLDER = "gridiron"
INCLUDE = ["metadata.xml", "main.lua", "content", "resources"]


def main():
    meta = (ROOT / "metadata.xml").read_text()
    version = re.search(r"<version>(.*?)</version>", meta).group(1).strip()
    if "--expect-version" in sys.argv:
        expected = sys.argv[sys.argv.index("--expect-version") + 1].lstrip("v")
        if expected != version:
            sys.exit(f"tag v{expected} does not match metadata.xml version {version}")

    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / f"{MOD_FOLDER}-v{version}.zip"

    files = []
    for entry in INCLUDE:
        path = ROOT / entry
        files.extend(sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path])

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in files:
            zf.write(f, f"{MOD_FOLDER}/{f.relative_to(ROOT).as_posix()}")
    print(f"{out.relative_to(ROOT)}  ({len(files)} files)")


if __name__ == "__main__":
    main()
