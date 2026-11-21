"""Check a recorded visual audit and its file identities. Never judge the art."""

from __future__ import annotations

import argparse
from datetime import date, datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys

CHECKS = {
    "shape_and_craft",
    "materials_and_lighting",
    "readability_in_play",
    "motion_and_effects",
    "integration_and_cost",
}
ALWAYS_APPLIES = {"readability_in_play", "integration_and_cost"}
EVIDENCE = {"godot_context", "close_up", "reproduction", "measurements"}
MISSING = {"", "unknown", "unassigned", "pending", "tbd", "n/a", "none", "not reviewed"}


def _object(value: object, label: str) -> dict:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _text(value: object, label: str) -> str:
    if not isinstance(value, str) or " ".join(value.casefold().split()) in MISSING:
        raise ValueError(f"{label} must be recorded")
    return value.strip()


def _unique_keys(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate receipt key: {key}")
        result[key] = value
    return result


def _relative_file(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if not path.parts or path.is_absolute() or ".." in path.parts or path.as_posix() != name \
            or ":" in name or "\\" in name or "\x00" in name:
        raise ValueError(f"expected a canonical relative file path: {name!r}")
    return path


def _audit_checks(receipt: dict) -> None:
    checks = _object(receipt.get("checks"), "checks")
    if checks.keys() != CHECKS:
        raise ValueError("checks must record every gate category exactly once")
    for key in sorted(CHECKS):
        check = _object(checks[key], f"checks.{key}")
        if check.get("result") == "PASS":
            continue
        if check.get("result") == "NOT_APPLICABLE" and key not in ALWAYS_APPLIES:
            _text(check.get("reason"), f"checks.{key}.reason")
            continue
        raise ValueError(f"checks.{key} is not approved")
    evidence = _object(receipt.get("evidence"), "evidence")
    required = EVIDENCE | ({"motion"} if checks["motion_and_effects"]["result"] == "PASS" else set())
    for key in sorted(required):
        _text(evidence.get(key), f"evidence.{key}")


def verify_receipt(receipt_path: Path, candidate_root: Path, proposed_files: list[str]) -> int:
    """Return the exact verified file count or raise; this is not art approval."""
    receipt = _object(json.loads(receipt_path.read_text(encoding="utf-8"), object_pairs_hook=_unique_keys), "receipt")
    if type(receipt.get("schema_version")) is not int or receipt["schema_version"] != 1:
        raise ValueError("schema_version must be 1")
    if receipt.get("result") != "PASS":
        raise ValueError("receipt must record an overall PASS")
    _text(receipt.get("scope"), "scope")
    author = _text(receipt.get("author"), "author")
    reviewer = _text(receipt.get("reviewer"), "reviewer")
    if " ".join(author.casefold().split()) == " ".join(reviewer.casefold().split()):
        raise ValueError("reviewer must be independent of the author")
    reviewed_on = _text(receipt.get("reviewed_on"), "reviewed_on")
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", reviewed_on):
        raise ValueError("reviewed_on must use YYYY-MM-DD")
    if date.fromisoformat(reviewed_on) > datetime.now(timezone.utc).date():
        raise ValueError("reviewed_on cannot be in the future")
    _audit_checks(receipt)

    files = _object(receipt.get("files"), "files")
    proposed = set(proposed_files)
    if not proposed or len(proposed) != len(proposed_files):
        raise ValueError("provide a nonempty proposed file set without duplicates")
    if files.keys() != proposed:
        missing = ", ".join(sorted(proposed - files.keys())) or "none"
        extra = ", ".join(sorted(files.keys() - proposed)) or "none"
        raise ValueError(f"receipt does not match the proposed files (not audited: {missing}; not proposed: {extra})")
    root = candidate_root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError("candidate root must be a directory")
    for name in sorted(proposed):
        path = root.joinpath(*_relative_file(name).parts)
        if path.resolve(strict=True) != path or not path.is_file():
            raise ValueError(f"{name}: expected a regular, non-symlink file inside candidate root")
        expected = files[name]
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise ValueError(f"{name}: expected a lowercase SHA-256 digest")
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(128 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected:
            raise ValueError(f"{name}: SHA-256 differs from the reviewed file; review again before publishing")
    return len(proposed)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path, help="path to an independent reviewer's completed JSON receipt")
    parser.add_argument("--candidate-root", type=Path, required=True, help="folder containing proposed files")
    parser.add_argument("--file", action="append", required=True, help="proposed file path relative to the root (repeat)")
    args = parser.parse_args(argv)
    try:
        count = verify_receipt(args.receipt, args.candidate_root, args.file)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Receipt rejected: {error}", file=sys.stderr)
        return 1
    print(f"Recorded PASS and SHA-256 verified for {count} file(s). This checker does not assess or approve visual quality.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
