"""List deployed battlefields and exact verified kit receipts without approving map art."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys

from .check_visual_audit_receipt import verify_receipt


@dataclass(frozen=True)
class Kit:
    name: str
    receipt: str
    battlefield: str
    asset: str
    file_count: int


# Reviewed placements, not a list of production-ready maps.
KITS = (
    Kit("Mine timber portal and connected shoulders (V10)", "docs/audits/mine-timber-portal-v10.json",
        "game/battlefields/year_one_mine_campaign.tscn",
        "assets/models/mine_timber_portal/mine_timber_portal.tscn", 30),
    Kit("Cut cemetery stair and retaining walls (V7)", "docs/audits/cut-cemetery-stair-v7.json",
        "game/battlefields/still_kingdom_cut.tscn", "assets/models/environment/cut_cemetery_stair.glb", 6),
)
DEVELOPMENT = "still uses development art"
ID = r"[a-z][a-z0-9_]*"
PACKED_RESOURCE = re.compile(
    r'^\[ext_resource type="PackedScene"(?: uid="[^"]+")? path="res://([^"]+)" id="([^"]+)"\]$', re.M,
)


def _table(root: Path, script: str, symbol: str) -> str:
    text = (root / "game" / script).read_text(encoding="utf-8")
    found = re.search(rf"^const {symbol} := \{{\n(.*?)^\}}$", text, re.M | re.S)
    if found is None:
        raise ValueError(f"{script} has no supported {symbol} table")
    return found[1]


def _deployments(root: Path) -> dict[str, str]:
    # These intentionally cover the checked-in authored declaration forms,
    # not general GDScript. Cross-check both tables rather than silently skip.
    catalog = _table(root, "campaign_missions.gd", "_BY_CAMPAIGN")
    expected = re.findall(rf'^\s*\{{"id": "({ID})", "title":', catalog, re.M)
    registry = _table(root, "campaign_deployments.gd", "_DEPLOYMENTS")
    entries = re.split(rf'^\t"({ID})": \{{\s*$', registry, flags=re.M)
    if not expected or len(expected) != len(set(expected)) or not entries[1:]:
        raise ValueError("expected nonempty, unique authored mission and deployment entries")
    deployments = {}
    for mission, body in zip(entries[1::2], entries[2::2]):
        scenes = re.findall(
            rf'^\s*"scene": preload\("res://(game/battlefield/{ID}\.tscn)"\),$', body, re.M,
        )
        if mission in deployments or len(scenes) != 1:
            raise ValueError(f"{mission}: expected one unique deployment and one supported scene preload")
        deployments[mission] = scenes[0]
    if set(expected) != deployments.keys():
        missing = sorted(set(expected) - deployments.keys())
        extra = sorted(deployments.keys() - set(expected))
        raise ValueError(f"catalog and deployment mission IDs differ (missing: {missing}; extra: {extra})")
    return {mission: deployments[mission] for mission in expected}


def _battlefield(root: Path, deployment: str) -> str:
    scene = (root / deployment).read_text(encoding="utf-8")
    selected = re.findall(r'^battlefield_scene = ExtResource\("([^"]+)"\)$', scene, re.M)
    paths = [path for path, key in PACKED_RESOURCE.findall(scene) if selected == [key]]
    if len(paths) != 1 or not re.fullmatch(rf"game/battlefields/{ID}\.tscn", paths[0]):
        raise ValueError(f"{deployment}: expected one explicit shared battlefield_scene resource")
    if not (root / paths[0]).is_file():
        raise ValueError(f"{deployment}: missing battlefield {paths[0]}")
    return paths[0]


def _verify_kit(root: Path, kit: Kit) -> dict:
    scene = (root / kit.battlefield).read_text(encoding="utf-8")
    keys = [key for path, key in PACKED_RESOURCE.findall(scene) if path == kit.asset]
    if len(keys) != 1 or not re.search(
        rf'^\[node [^\n]*instance=ExtResource\("{re.escape(keys[0])}"\)\]$', scene, re.M,
    ):
        raise ValueError(f"{kit.name}: reviewed kit is not instanced in its stated battlefield")
    receipt_path = root / kit.receipt
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    files = receipt.get("files") if isinstance(receipt, dict) else None
    if not isinstance(files, dict) or len(files) != kit.file_count or not {kit.asset, kit.battlefield} <= files.keys():
        raise ValueError(f"{kit.receipt}: expected all {kit.file_count} reviewed files, including the kit and placement")
    return {"name": kit.name, "receipt": kit.receipt, "verified_files": verify_receipt(receipt_path, root, list(files))}


def build_report(root: Path) -> dict:
    deployments = _deployments(root)
    battlefields = {mission: _battlefield(root, scene) for mission, scene in deployments.items()}
    verified = {}
    for kit in KITS:
        if kit.battlefield not in battlefields.values():
            raise ValueError(f"{kit.name}: reviewed placement is not used by a campaign deployment")
        verified.setdefault(kit.battlefield, []).append(_verify_kit(root, kit))
    return {
        "notice": "Kit receipts cover only their listed art and placements, not the battlefield or deployment.",
        "deployment_count": len(deployments),
        "deployments": [
            {
                "mission_id": mission,
                "deployment_scene": scene,
                "battlefield_scene": battlefields[mission],
                "art_status": DEVELOPMENT,
                "verified_kit_receipts": verified.get(battlefields[mission], []),
            }
            for mission, scene in deployments.items()
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args(argv)
    try:
        report = build_report(Path(__file__).resolve().parents[1])
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Deployment art report rejected: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
