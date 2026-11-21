"""List deployed battlefields and exact verified kit receipts without approving map art."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
import sys

from .check_visual_audit_receipt import _text, verify_receipt


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
    Kit("Cut Record Room exterior (V3.1)", "docs/audits/cut-record-room-v31.json",
        "game/battlefields/still_kingdom_cut.tscn", "assets/models/environment/record_room.glb", 6),
    Kit("Red Basin lower storehouse (V1.2)", "docs/audits/red-basin-storehouse-v12.json",
        "game/battlefields/red_basin_well_road.tscn", "assets/models/environment/basin_storehouse.glb", 6),
    Kit("Keeper Boundary Post shelter (V1.1)", "docs/audits/keeper-boundary-shelter-v11.json",
        "game/battlefields/cairnspine_boundary_post.tscn", "assets/models/environment/keeper_shelter.glb", 6),
)
CUT_KIT = KITS[1]
CUT_ORIGINAL_RECEIPT_SHA256 = "cebadd861eab16ddcbb773f75bf7b5014b967d9db7479ceaf4e4d53ce66868c6"
CUT_CONTINUITY_RECEIPT = "docs/audits/cut-cemetery-stair-v7-continuity.json"
# Pin only after independent sign-off on the replacement host and continuity evidence.
CUT_CONTINUITY_RECEIPT_SHA256: str | None = "17c488b20a6b180823516640bc9955a4186211c2eb1a2ba2dc14c0cfbed6cfd8"

CASE_MISSION = "mara_mine_escort"
CASE_DEPLOYMENT = "game/battlefield/mara_mine_escort_campaign.tscn"
GREYHOLLOW_RESCUE = "game/battlefield/mara_greyhollow_rescue_campaign.tscn"
CASE_BASE = "game/battlefield/mara_mine_escort.tscn"
CASE_CONSUMER = "game/battlefield/mara_mine_escort.gd"
CASE_VISUAL = "assets/models/environment/godbridle_case_visual.gd"
CASE_ASSET = "assets/models/environment/godbridle_custody_case.glb"
CASE_RECEIPT = "docs/audits/godbridle-custody-case-v3.json"
WHEEL_MISSION = "orc_spanwater_release"
WHEEL_DEPLOYMENT = "game/battlefield/raska_spanwater.tscn"
WHEEL_BATTLEFIELD = "game/battlefields/spanwater_lock_campaign.tscn"
WHEEL_BINDING = "game/battlefield/props/raska_spillway_wheel_binding.gd"
WHEEL_ASSET = "assets/models/environment/raska_spillway_wheel/spillway_wheel.tscn"
WHEEL_RECEIPT = "docs/audits/raska-spanwater-wheel-v11.json"
BEACH_MISSION = "ilyra_coast_survey"
BEACH_DEPLOYMENT = "game/battlefield/ilyra_coast_survey_campaign.tscn"
BEACH_BATTLEFIELD = "game/battlefields/moonwash_survey_shore.tscn"
BEACH_BINDING = "game/battlefield/props/ilyra_beach_signal_stand_binding.gd"
BEACH_ASSET = "assets/models/environment/ilyra_beach_signal/beach_signal_stand.tscn"
BEACH_RECEIPT = "docs/audits/ilyra-beach-signal-stand-v1.json"
HEADLAND_BINDING = "game/battlefield/props/ilyra_headland_relay_binding.gd"
HEADLAND_ASSET = "assets/models/environment/ilyra_headland_relay/headland_relay.glb"
HEADLAND_SOURCE = "assets/source/moonwash_survey_shore/headland_relay.blend"
HEADLAND_RECEIPT = "docs/audits/ilyra-headland-relay-v1.json"
QUAY_MISSION = "mara_moonwash_quay"
QUAY_DEPLOYMENT = "game/battlefield/mara_moonwash_playtest.tscn"
QUAY_WRAPPER = "game/battlefields/moonwash_harbor_campaign_mara_exit.tscn"
QUAY_BASE = "game/battlefields/moonwash_harbor_campaign.tscn"
QUAY_ASSET = "assets/models/environment/quay_threshold.glb"
QUAY_RECEIPT = "docs/audits/mara-high-quay-threshold-v1.json"
BRIDGE_MISSION = "mara_grain_crossing"
BRIDGE_DEPLOYMENT = "game/battlefield/mara_grain_crossing_campaign.tscn"
BRIDGE_BATTLEFIELD = "game/battlefields/marches_crossing.tscn"
BRIDGE_BINDING = "game/battlefield/mara_grain_bridge_visual.gd"
BRIDGE_NEAR = "assets/models/environment/marches_north_timber_bridge.glb"
BRIDGE_SECTOR = "assets/models/environment/marches_north_timber_bridge_sector.glb"
BRIDGE_RECEIPT = "docs/audits/mara-marches-north-bridge-v1.json"
VAULT_MISSION = "sova_vault_return"
VAULT_DEPLOYMENT = "game/battlefield/sova_vault_return_playtest.tscn"
VAULT_WRAPPER = "game/battlefields/cairnspine_vault_road_sova_jamb.tscn"
VAULT_BASE = "game/battlefields/cairnspine_vault_road.tscn"
VAULT_ASSET = "assets/models/environment/vault_jamb.glb"
VAULT_RECEIPT = "docs/audits/sova-vault-jambs-v1.json"
VAULT_STOCK_DEPLOYMENTS = ("sova_public_record", "neris_cairnspine_passage", "sereth_no_proxy")
STOREHOUSE_FIELD = "game/battlefields/year_one_mine_campaign.tscn"
STOREHOUSE_BINDING = "game/battlefield/mara_mine_storehouse_art.gd"
STOREHOUSE_SOURCE = "assets/models/environment/mara_mine_storehouse/works_shell.gd"
STOREHOUSE_FAR = "assets/models/environment/mara_mine_storehouse/works_shell_far.gd"
STOREHOUSE_RECEIPT = "docs/audits/mara-mine-storehouse-v1.json"
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
    scene_bytes = (root / kit.battlefield).read_bytes()
    scene = scene_bytes.decode("utf-8")
    keys = [key for path, key in PACKED_RESOURCE.findall(scene) if path == kit.asset]
    if len(keys) != 1 or not re.search(
        rf'^\[node [^\n]*instance=ExtResource\("{re.escape(keys[0])}"\)\]$', scene, re.M,
    ):
        raise ValueError(f"{kit.name}: reviewed kit is not instanced in its stated battlefield")
    receipt = _cut_receipt(root, scene_bytes) if kit == CUT_KIT else kit.receipt
    record = _receipt_record(root, kit.name, receipt, kit.file_count, {kit.asset, kit.battlefield},
                             "shared_battlefield", kit.battlefield)
    if receipt != kit.receipt:
        record["previous_receipt"] = kit.receipt
    return record


def _pinned_receipt(root: Path, relative: str, expected: str) -> dict:
    path = root.resolve() / relative
    if path.resolve(strict=True) != path or not path.is_file():
        raise ValueError(f"{relative}: expected a regular, non-symlink review record")
    payload = path.read_bytes()
    if hashlib.sha256(payload).hexdigest() != expected:
        raise ValueError(f"{relative}: receipt bytes do not match the pinned review")
    document = json.loads(payload)
    if not isinstance(document, dict):
        raise ValueError(f"{relative}: expected a JSON object")
    return document


def _cut_receipt(root: Path, scene_bytes: bytes) -> str:
    original = _pinned_receipt(root, CUT_KIT.receipt, CUT_ORIGINAL_RECEIPT_SHA256)
    original_files = original["files"]
    host = CUT_KIT.battlefield
    scene_digest = hashlib.sha256(scene_bytes).hexdigest()
    if scene_digest == original_files[host]:
        return CUT_KIT.receipt
    if CUT_CONTINUITY_RECEIPT_SHA256 is None:
        raise ValueError(f"{host}: SHA-256 differs from the original approved host; no pinned continuity review")
    continuation = _pinned_receipt(root, CUT_CONTINUITY_RECEIPT, CUT_CONTINUITY_RECEIPT_SHA256)
    if continuation.get("continuity") != {
        "previous_receipt": CUT_KIT.receipt,
        "previous_receipt_sha256": CUT_ORIGINAL_RECEIPT_SHA256,
        "battlefield": host,
        "previous_battlefield_sha256": original_files[host],
    }:
        raise ValueError(f"{CUT_CONTINUITY_RECEIPT}: continuity does not anchor the original Cut placement")
    evidence = continuation.get("evidence")
    _text(evidence.get("continuity") if isinstance(evidence, dict) else None, "evidence.continuity")
    files = continuation.get("files")
    if not isinstance(files, dict) or files.keys() != original_files.keys() or any(
        files[path] != expected for path, expected in original_files.items() if path != host
    ):
        raise ValueError(f"{CUT_CONTINUITY_RECEIPT}: continuity may replace only the reviewed host digest")
    if files[host] != scene_digest:
        raise ValueError(f"{host}: SHA-256 differs from the exact continuity review host")
    # The caller applies the unmodified full PASS verifier to this entire file set.
    return CUT_CONTINUITY_RECEIPT


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


def _verify_greyhollow_rescue(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> None:
    # The old escort's case and storehouse receipts are not approvals for a new
    # mission context. The rescue keeps the exact shared field but not the case.
    if deployments.get(CASE_MISSION) != GREYHOLLOW_RESCUE or battlefields.get(CASE_MISSION) != STOREHOUSE_FIELD:
        raise ValueError("Greyhollow rescue: expected the explicit rescue deployment and original Mine field")
    scene = (root / GREYHOLLOW_RESCUE).read_text(encoding="utf-8")
    parent_keys = [key for path, key in PACKED_RESOURCE.findall(scene) if path == CASE_DEPLOYMENT]
    if len(parent_keys) != 1 or not re.search(
        rf'^\[node name="[^"]+" instance=ExtResource\("{re.escape(parent_keys[0])}"\)\]$', scene, re.M,
    ):
        raise ValueError("Greyhollow rescue: expected the original Mine campaign scene as its parent")
    if re.findall(r'^custody_case_scene = (.+)$', scene, re.M) != ["null"] or CASE_ASSET in scene:
        raise ValueError("Greyhollow rescue: the custody case must not appear in the rescue")


def _verify_raska_spillway_wheel(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> dict:
    # Unlike a shared kit, the wheel's reviewed replacement is an opt-in child
    # of one deployment. The other Spanwater missions inherit the stock wheel.
    if deployments.get(WHEEL_MISSION) != WHEEL_DEPLOYMENT or battlefields.get(WHEEL_MISSION) != WHEEL_BATTLEFIELD:
        raise ValueError("Raska spillway wheel: reviewed placement is not registered")
    _verify_adapter(root, WHEEL_DEPLOYMENT, WHEEL_BINDING, "SpillwayWheelVisualBinding", "Raska spillway wheel")
    return _receipt_record(root, "Raska’s Spanwater spillway wheel and stand (V1.1)", WHEEL_RECEIPT, 8,
                           {WHEEL_ASSET, WHEEL_BINDING}, "mission_deployment", WHEEL_DEPLOYMENT)


def _verify_ilyra_beach_stand(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> dict:
    if deployments.get(BEACH_MISSION) != BEACH_DEPLOYMENT or battlefields.get(BEACH_MISSION) != BEACH_BATTLEFIELD:
        raise ValueError("Ilyra Beach Signal Stand: reviewed placement is not registered")
    _verify_adapter(root, BEACH_DEPLOYMENT, BEACH_BINDING, "BeachSignalStandBinding", "Ilyra Beach Signal Stand")
    return _receipt_record(root, "Ilyra’s fixed Beach Relay signal stand (V1)", BEACH_RECEIPT, 7,
                           {BEACH_ASSET, BEACH_BINDING}, "mission_deployment", BEACH_DEPLOYMENT)


def _verify_ilyra_headland_relay(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> dict:
    if [mission for mission, scene in deployments.items() if scene == BEACH_DEPLOYMENT] != [BEACH_MISSION] \
            or battlefields.get(BEACH_MISSION) != BEACH_BATTLEFIELD:
        raise ValueError("Ilyra Headland Relay: reviewed placement is not registered")
    _verify_adapter(root, BEACH_DEPLOYMENT, HEADLAND_BINDING, "HeadlandRelayBinding", "Ilyra Headland Relay")
    return _receipt_record(root, "Ilyra’s fixed Headland Relay (V1)", HEADLAND_RECEIPT, 12,
                           {HEADLAND_ASSET, HEADLAND_BINDING, HEADLAND_SOURCE, BEACH_BATTLEFIELD},
                           "mission_deployment", BEACH_DEPLOYMENT)


def _verify_mara_quay_threshold(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> dict:
    if deployments.get(QUAY_MISSION) != QUAY_DEPLOYMENT or [
        mission for mission, field in battlefields.items() if field == QUAY_WRAPPER
    ] != [QUAY_MISSION]:
        raise ValueError("Mara High Quay threshold: wrapper is not isolated to its reviewed placement")
    if battlefields.get("ilyra_moonwash_rescue") != QUAY_BASE:
        raise ValueError("Mara High Quay threshold: Ilyra must still use the unmodified shared harbor binding")
    return _receipt_record(root, "Mara’s fixed Upper Quay threshold (V1)", QUAY_RECEIPT, 7,
                           {QUAY_ASSET, QUAY_WRAPPER, QUAY_BASE}, "mission_deployment", QUAY_DEPLOYMENT)


def _verify_mara_north_bridge(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> dict:
    if [mission for mission, scene in deployments.items() if scene == BRIDGE_DEPLOYMENT] != [BRIDGE_MISSION] \
            or battlefields.get(BRIDGE_MISSION) != BRIDGE_BATTLEFIELD:
        raise ValueError("Mara North Bridge: exact camera binding is not isolated to its reviewed deployment")
    return _receipt_record(root, "Mara’s North Bridge (V1 near and sector)", BRIDGE_RECEIPT, 10,
                           {BRIDGE_NEAR, BRIDGE_SECTOR, BRIDGE_DEPLOYMENT, BRIDGE_BINDING, BRIDGE_BATTLEFIELD},
                           "mission_deployment", BRIDGE_DEPLOYMENT)


def _verify_sova_vault_jambs(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> dict:
    if deployments.get(VAULT_MISSION) != VAULT_DEPLOYMENT or [
        mission for mission, field in battlefields.items() if field == VAULT_WRAPPER
    ] != [VAULT_MISSION]:
        raise ValueError("Sova Vault jambs: wrapper is not isolated to its reviewed placement")
    if any(battlefields.get(mission) != VAULT_BASE for mission in VAULT_STOCK_DEPLOYMENTS):
        raise ValueError("Sova Vault jambs: the other three missions must still use the shared Cairnspine field")
    return _receipt_record(root, "Sova’s fixed Vault jambs and capitals (V1)", VAULT_RECEIPT, 7,
                           {VAULT_ASSET, VAULT_WRAPPER, VAULT_BASE}, "mission_deployment", VAULT_DEPLOYMENT)


def _verify_mara_storehouse(root: Path, deployments: dict[str, str], battlefields: dict[str, str]) -> dict:
    if deployments.get(CASE_MISSION) != CASE_DEPLOYMENT or battlefields.get(CASE_MISSION) != STOREHOUSE_FIELD:
        raise ValueError("Mara Mine Storehouse: reviewed registered placement and original Mine field are required")
    _verify_adapter(root, CASE_DEPLOYMENT, STOREHOUSE_BINDING, "StorehouseArt", "Mara Mine Storehouse")
    if any(STOREHOUSE_BINDING in (root / scene).read_text(encoding="utf-8")
           for mission, scene in deployments.items() if mission != CASE_MISSION):
        raise ValueError("Mara Mine Storehouse: the adapter is scoped to Mara’s Mine only")
    return _receipt_record(root, "Mara’s closed Mine Storehouse and roof (V1 near and far)", STOREHOUSE_RECEIPT, 11,
                           {STOREHOUSE_FIELD, STOREHOUSE_BINDING, STOREHOUSE_SOURCE, STOREHOUSE_FAR},
                           "mission_deployment", CASE_DEPLOYMENT)


def _verify_adapter(root: Path, deployment: str, script: str, node: str, context: str) -> None:
    scene = (root / deployment).read_text(encoding="utf-8")
    ext = re.findall(rf'^\[ext_resource type="Script" path="res://{re.escape(script)}" id="([^"]+)"\]$',
                     scene, re.M)
    mounted = re.findall(
        rf'^\[node name="{re.escape(node)}" type="Node" parent="\."\]\nscript = ExtResource\("([^"]+)"\)$',
        scene, re.M,
    )
    if len(ext) != 1 or ext != mounted:
        raise ValueError(f"{context}: exact adapter is not attached to its deployment")


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
    _verify_greyhollow_rescue(root, deployments, battlefields)
    spillway_wheel = _verify_raska_spillway_wheel(root, deployments, battlefields)
    beach_stand = _verify_ilyra_beach_stand(root, deployments, battlefields)
    headland_relay = _verify_ilyra_headland_relay(root, deployments, battlefields)
    quay_threshold = _verify_mara_quay_threshold(root, deployments, battlefields)
    north_bridge = _verify_mara_north_bridge(root, deployments, battlefields)
    vault_jambs = _verify_sova_vault_jambs(root, deployments, battlefields)
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
                + ([spillway_wheel] if mission == WHEEL_MISSION else [])
                + ([beach_stand, headland_relay] if mission == BEACH_MISSION else [])
                + ([quay_threshold] if mission == QUAY_MISSION else [])
                + ([north_bridge] if mission == BRIDGE_MISSION else [])
                + ([vault_jambs] if mission == VAULT_MISSION else []),
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
