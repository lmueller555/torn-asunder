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
CASE_MISSION = "mara_mine_escort"
CASE_DEPLOYMENT = "game/battlefield/mara_mine_escort_campaign.tscn"
CASE_BASE = "game/battlefield/mara_mine_escort.tscn"
CASE_CONSUMER = "game/battlefield/mara_mine_escort.gd"
CASE_VISUAL = "assets/models/environment/godbridle_case_visual.gd"
CASE_ASSET = "assets/models/environment/godbridle_custody_case.glb"
CASE_RECEIPT = "docs/audits/godbridle-custody-case-v3.json"
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
    return _receipt_record(root, kit.name, kit.receipt, kit.file_count, {kit.asset, kit.battlefield},
                           "shared_battlefield", kit.battlefield)


def _verify_custody_case(root: Path, deployments: dict[str, str]) -> dict:
    # The case is enabled in Mara's mission scene, not in the shared Mine.
    if deployments.get(CASE_MISSION) != CASE_DEPLOYMENT:
        raise ValueError("Godbridle custody case: Mara's reviewed deployment scene is not registered")
    scene = (root / CASE_DEPLOYMENT).read_text(encoding="utf-8")
    node = re.search(r'^\[node [^\n]+\]\n(.*?)(?=^\[|\Z)', scene, re.M | re.S)
    selected = re.findall(r'^custody_case_scene = ExtResource\("([^"]+)"\)$', node[1], re.M) if node else []
    resources = [path for path, key in PACKED_RESOURCE.findall(scene) if selected == [key]]
    if resources != [CASE_ASSET]:
        raise ValueError("Godbridle custody case: Mara's deployment does not select the reviewed case")
    parents = [key for path, key in PACKED_RESOURCE.findall(scene) if path == CASE_BASE]
    if len(parents) != 1 or not re.search(
        rf'^\[node name="[^"]+" instance=ExtResource\("{re.escape(parents[0])}"\)\]$', scene, re.M,
    ):
        raise ValueError("Godbridle custody case: Mara's deployment no longer inherits its reviewed binding")
    base = (root / CASE_BASE).read_text(encoding="utf-8")
    selected_script = re.search(r'^script = ExtResource\("([^"]+)"\)$', base, re.M)
    code = {line.strip() for line in (root / CASE_CONSUMER).read_text(encoding="utf-8").splitlines()}
    binding = {
        "@export var custody_case_scene: PackedScene",
        f'const CustodyCaseVisual := preload("res://{CASE_VISUAL}")',
        "_custody_case = CustodyCaseVisual.new(custody_case_scene.instantiate() as Node3D)",
        "prop.add_child(_custody_case)",
    }
    if (selected_script is None
        or f'[ext_resource type="Script" path="res://{CASE_CONSUMER}" id="{selected_script[1]}"]' not in base.splitlines()
        or not binding <= code):
        raise ValueError("Godbridle custody case: current Mara consumer does not instantiate the reviewed visual")
    return _receipt_record(root, "Sealed Godbridle custody case (V3)", CASE_RECEIPT, 10, {CASE_ASSET, CASE_VISUAL},
                           "mission_deployment", CASE_DEPLOYMENT)


def _receipt_record(root: Path, name: str, receipt: str, file_count: int, required: set[str],
                    placement_scope: str, placement_scene: str) -> dict:
    receipt_path = root / receipt
    data = json.loads(receipt_path.read_text(encoding="utf-8"))
    files = data.get("files") if isinstance(data, dict) else None
    if not isinstance(files, dict) or len(files) != file_count or not required <= files.keys():
        raise ValueError(f"{receipt}: expected all {file_count} reviewed files and required scope")
    return {
        "name": name,
        "receipt": receipt,
        "verified_files": verify_receipt(receipt_path, root, list(files)),
        "placement_scope": placement_scope,
        "placement_scene": placement_scene,
    }


def build_report(root: Path) -> dict:
    deployments = _deployments(root)
    battlefields = {mission: _battlefield(root, scene) for mission, scene in deployments.items()}
    verified = {}
    for kit in KITS:
        if kit.battlefield not in battlefields.values():
            raise ValueError(f"{kit.name}: reviewed placement is not used by a campaign deployment")
        verified.setdefault(kit.battlefield, []).append(_verify_kit(root, kit))
    custody_case = _verify_custody_case(root, deployments)
    return {
        "notice": "Kit receipts cover only their listed art and placements, not the battlefield or deployment.",
        "deployment_count": len(deployments),
        "deployments": [
            {
                "mission_id": mission,
                "deployment_scene": scene,
                "battlefield_scene": battlefields[mission],
                "art_status": DEVELOPMENT,
                "verified_kit_receipts": verified.get(battlefields[mission], [])
                + ([custody_case] if mission == CASE_MISSION else []),
            }
            for mission, scene in deployments.items()
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--require-release-ready", action="store_true",
        help="reject the registered campaign deployments if any lack full visual approval",
    )
    args = parser.parse_args(argv)
    try:
        report = build_report(Path(__file__).resolve().parents[1])
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Deployment art report rejected: {error}", file=sys.stderr)
        return 1
    if args.require_release_ready:
        # All current rows are development-only. A kit receipt never approves a deployment.
        blocked = [row["mission_id"] for row in report["deployments"] if row["art_status"] != "release_approved"]
        if blocked:
            print(f"Campaign release art check failed: {len(blocked)} deployments lack full visual approval.",
                  file=sys.stderr)
            for mission in blocked:
                print(f"  {mission}", file=sys.stderr)
            return 2
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
