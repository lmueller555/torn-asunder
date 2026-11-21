"""Require independently recorded receipts for changed tracked asset payloads."""

from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys

from .check_visual_audit_receipt import verify_receipt

ART_SUFFIXES = {
    ".blend", ".fbx", ".gltf", ".glb", ".obj", ".mtl",
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".tga", ".dds", ".ktx", ".ktx2", ".hdr", ".exr",
    ".ttf", ".otf", ".woff", ".woff2",
    ".tscn", ".scn", ".tres", ".res", ".gdshader", ".gdshaderinc", ".material",
}


def _asset(path: str) -> bool:
    value = PurePosixPath(path)
    if len(value.parts) < 2 or value.parts[0] != "assets":
        return False
    # Sidecars can change what the engine imports without changing the source bytes.
    name = value.name.lower()
    for sidecar in (".import", ".uid"):
        name = name.removesuffix(sidecar)
    suffix = PurePosixPath(name).suffix
    return suffix in ART_SUFFIXES or (value.parts[1] == "models" and suffix == ".gd")


def _receipt(path: str) -> bool:
    value = PurePosixPath(path)
    return value.parent == PurePosixPath("docs/audits") and value.suffix == ".json"


def check_changed_art(root: Path, changed_paths: list[str]) -> set[str]:
    assets = {path for path in changed_paths if _asset(path)}
    covered: set[str] = set()
    for relative in sorted(path for path in set(changed_paths) if _receipt(path)):
        receipt = root / relative
        if receipt.resolve(strict=True) != root.resolve() / relative or not receipt.is_file():
            raise ValueError(f"{relative}: expected a regular receipt, not a symlink")
        data = json.loads(receipt.read_text(encoding="utf-8"))
        files = data.get("files") if isinstance(data, dict) else None
        if not isinstance(files, dict):
            raise ValueError(f"{relative}: files must record the reviewed candidate")
        verify_receipt(receipt, root, list(files))
        covered.update(assets.intersection(files))
    missing = sorted(assets - covered)
    if missing:
        raise ValueError("no new or updated exact PASS receipt for:\n  " + "\n  ".join(missing))
    return covered


def _tracked_changed_paths(root: Path, base: str) -> list[str]:
    # Resolve a commit first so CLI values never act as options to git diff.
    run = subprocess.run(
        ["git", "rev-parse", "--verify", "--end-of-options", base + "^{commit}"],
        cwd=root, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    sha = run.stdout.strip()
    # Compare the checked-out proposal to its base. Treat rename/copy destinations
    # as additions; deleting an art payload alone does not require a new receipt.
    result = subprocess.run(
        ["git", "diff", "--no-renames", "--diff-filter=AMT", "--name-only", "-z", sha, "--"],
        cwd=root, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    return [part.decode("utf-8") for part in result.stdout.split(b"\x00") if part]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="base commit for the checked-out change")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    try:
        covered = check_changed_art(root, _tracked_changed_paths(root, args.base))
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Changed art check rejected: {error}", file=sys.stderr)
        return 1
    print(f"Changed art check verified {len(covered)} tracked asset file(s). This is not a visual approval.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
