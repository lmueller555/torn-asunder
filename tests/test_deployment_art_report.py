"""The export is read-only and never promotes a kit receipt to map approval."""

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools.report_deployment_art import DEVELOPMENT, KITS, _battlefield, _deployments, _verify_kit, build_report


ROOT = Path(__file__).resolve().parents[1]


class DeploymentArtReportTest(unittest.TestCase):
    def test_current_live_campaign_art(self):
        report = build_report(ROOT)
        rows = {row["mission_id"]: row for row in report["deployments"]}
        self.assertEqual(report["deployment_count"], 18)
        self.assertEqual(len(rows), 18)
        self.assertTrue(all(row["art_status"] == DEVELOPMENT for row in rows.values()))
        self.assertEqual(
            {mission for mission, row in rows.items() if row["verified_kit_receipts"]},
            {"mara_mine_escort", "orc_mine_witness", "sova_mine_tunnels", "sereth_voices_at_the_cut"},
        )
        for mission in ["mara_mine_escort", "orc_mine_witness", "sova_mine_tunnels"]:
            self.assertEqual(rows[mission]["battlefield_scene"], KITS[0].battlefield)
            self.assertEqual(rows[mission]["verified_kit_receipts"][0]["receipt"], KITS[0].receipt)
            self.assertEqual(rows[mission]["verified_kit_receipts"][0]["verified_files"], 30)
        cut = rows["sereth_voices_at_the_cut"]
        self.assertEqual(cut["battlefield_scene"], KITS[1].battlefield)
        self.assertEqual(cut["verified_kit_receipts"][0]["receipt"], KITS[1].receipt)
        self.assertEqual(cut["verified_kit_receipts"][0]["verified_files"], 6)
        self.assertEqual(rows["sereth_pass_writ"]["verified_kit_receipts"], [])

    def test_catalog_and_registry_cannot_silently_diverge_or_be_empty(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "game").mkdir()
            for name in ("campaign_missions.gd", "campaign_deployments.gd"):
                shutil.copyfile(ROOT / "game" / name, root / "game" / name)
            registry = root / "game/campaign_deployments.gd"
            original = registry.read_text()
            registry.write_text(original.replace('\t"orc_mine_witness": {', '\t"unrecognized_mission": {'))
            with self.assertRaisesRegex(ValueError, "catalog and deployment mission IDs differ"):
                _deployments(root)
            registry.write_text("const _DEPLOYMENTS := {\n}\n")
            with self.assertRaisesRegex(ValueError, "nonempty"):
                _deployments(root)

    def test_a_declared_but_unselected_scene_is_not_a_deployed_battlefield(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            deployment = "game/battlefield/example.tscn"
            (root / deployment).parent.mkdir(parents=True)
            (root / deployment).write_text(
                '[ext_resource type="PackedScene" path="res://%s" id="1_map"]\n'
                'battlefield_scene = ExtResource("2_other")\n' % KITS[0].battlefield,
            )
            with self.assertRaisesRegex(ValueError, "one explicit shared battlefield_scene"):
                _battlefield(root, deployment)

    def test_kit_coverage_is_not_inferred_from_a_receipt_or_declared_dependency(self):
        kit = KITS[1]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            original = json.loads((ROOT / kit.receipt).read_text())
            for path in [kit.receipt, *original["files"]]:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, root / path)
            # A legitimate receipt stops certifying the export after one byte changes.
            self.assertEqual(_verify_kit(root, kit)["verified_files"], 6)
            with (root / kit.asset).open("ab") as asset:
                asset.write(b"\x00")
            with self.assertRaisesRegex(ValueError, "SHA-256 differs"):
                _verify_kit(root, kit)
            # The expected reviewed set cannot silently lose a supporting file.
            original["files"].pop(next(path for path in original["files"] if path.endswith(".uid")))
            (root / kit.receipt).write_text(json.dumps(original))
            with self.assertRaisesRegex(ValueError, "expected all 6 reviewed files"):
                _verify_kit(root, kit)
            # A map dependency needs an actual instance, not just an ext_resource.
            scene = root / kit.battlefield
            scene.write_text("\n".join(line for line in scene.read_text().splitlines()
                                       if 'instance=ExtResource("1_stair")' not in line))
            with self.assertRaisesRegex(ValueError, "not instanced"):
                _verify_kit(root, kit)
