"""The export is read-only and never promotes a kit receipt to map approval."""

from contextlib import redirect_stderr, redirect_stdout
import hashlib
from io import StringIO
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from tools.report_deployment_art import (
    CASE_BASE, CASE_CONSUMER, CASE_DEPLOYMENT, CASE_MISSION, CASE_RECEIPT, CUT_CONTINUITY_RECEIPT,
    CUT_KIT, CUT_ORIGINAL_RECEIPT_SHA256, DEVELOPMENT, KITS,
    _battlefield, _deployments, _verify_custody_case, _verify_kit, build_report, main,
)


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
            {"mara_mine_escort", "orc_mine_witness", "sova_mine_tunnels", "sereth_voices_at_the_cut", "orc_well_road", "sereth_pass_writ"},
        )
        for mission in ["mara_mine_escort", "orc_mine_witness", "sova_mine_tunnels"]:
            self.assertEqual(rows[mission]["battlefield_scene"], KITS[0].battlefield)
            self.assertEqual(rows[mission]["verified_kit_receipts"][0]["receipt"], KITS[0].receipt)
            self.assertEqual(rows[mission]["verified_kit_receipts"][0]["verified_files"], 30)
        self.assertEqual(
            [row["receipt"] for row in rows[CASE_MISSION]["verified_kit_receipts"]],
            [KITS[0].receipt, CASE_RECEIPT],
        )
        case = rows[CASE_MISSION]["verified_kit_receipts"][1]
        self.assertEqual(case["placement_scope"], "mission_deployment")
        self.assertEqual(case["placement_scene"], CASE_DEPLOYMENT)
        self.assertEqual(case["verified_files"], 10)
        self.assertEqual(
            {m for m, row in rows.items() if any(kit["receipt"] == CASE_RECEIPT
                                                for kit in row["verified_kit_receipts"])},
            {CASE_MISSION},
        )
        self.assertEqual(rows["orc_mine_witness"]["verified_kit_receipts"][0]["placement_scope"],
                         "shared_battlefield")
        cut = rows["sereth_voices_at_the_cut"]
        self.assertEqual(cut["battlefield_scene"], KITS[1].battlefield)
        stair = cut["verified_kit_receipts"][0]
        previous = json.loads((ROOT / CUT_KIT.receipt).read_text())["files"][CUT_KIT.battlefield]
        current = hashlib.sha256((ROOT / CUT_KIT.battlefield).read_bytes()).hexdigest()
        self.assertEqual(stair["receipt"], CUT_KIT.receipt if current == previous else CUT_CONTINUITY_RECEIPT)
        if current != previous:
            self.assertEqual(stair["previous_receipt"], CUT_KIT.receipt)
        self.assertEqual(stair["verified_files"], 6)
        self.assertEqual([item["receipt"] for item in cut["verified_kit_receipts"][1:]],
                         ["docs/audits/cut-record-room-v31.json"])
        self.assertEqual(cut["verified_kit_receipts"][1]["verified_files"], 6)
        self.assertEqual(cut["verified_kit_receipts"][1]["placement_scope"], "shared_battlefield")
        boundary = rows["sereth_pass_writ"]["verified_kit_receipts"]
        self.assertEqual(len(boundary), 1)
        self.assertEqual(boundary[0]["receipt"], "docs/audits/keeper-boundary-shelter-v11.json")
        self.assertEqual(boundary[0]["placement_scope"], "shared_battlefield")
        self.assertEqual(boundary[0]["verified_files"], 6)
        basin = rows["orc_well_road"]["verified_kit_receipts"]
        self.assertEqual(len(basin), 1)
        self.assertEqual(basin[0]["receipt"], "docs/audits/red-basin-storehouse-v12.json")
        self.assertEqual(basin[0]["placement_scope"], "shared_battlefield")
        self.assertEqual(basin[0]["verified_files"], 6)

    def test_release_check_rejects_every_development_deployment_even_with_a_passed_kit(self):
        out, err = StringIO(), StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            self.assertEqual(main(["--require-release-ready"]), 2)
        self.assertEqual(out.getvalue(), "")
        diagnostics = err.getvalue().splitlines()
        self.assertIn("18 deployments lack full visual approval", diagnostics[0])
        missions = [row["mission_id"] for row in build_report(ROOT)["deployments"]]
        self.assertCountEqual([line.strip() for line in diagnostics[1:]], missions)
        self.assertIn(CASE_MISSION, missions)  # A passing custody case is not a passing map.

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
            stair = next(row for row in build_report(ROOT)["deployments"]
                         if row["mission_id"] == "sereth_voices_at_the_cut")["verified_kit_receipts"][0]
            for path in {kit.receipt, stair["receipt"], *original["files"]}:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, root / path)
            # A legitimate receipt stops certifying the export after one byte changes.
            self.assertEqual(_verify_kit(root, kit)["verified_files"], 6)
            with (root / kit.asset).open("ab") as asset:
                asset.write(b"\x00")
            with self.assertRaisesRegex(ValueError, "SHA-256 differs"):
                _verify_kit(root, kit)
            # The historical approval cannot silently lose a supporting file.
            original["files"].pop(next(path for path in original["files"] if path.endswith(".uid")))
            (root / kit.receipt).write_text(json.dumps(original))
            with self.assertRaisesRegex(ValueError, "receipt bytes do not match the pinned review"):
                _verify_kit(root, kit)
            # A map dependency needs an actual instance, not just an ext_resource.
            scene = root / kit.battlefield
            scene.write_text("\n".join(line for line in scene.read_text().splitlines()
                                       if 'instance=ExtResource("1_stair")' not in line))
            with self.assertRaisesRegex(ValueError, "not instanced"):
                _verify_kit(root, kit)

    def test_case_depends_on_current_mara_binding_not_historical_script_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            files = json.loads((ROOT / CASE_RECEIPT).read_text())["files"]
            for path in [CASE_RECEIPT, CASE_BASE, CASE_DEPLOYMENT, CASE_CONSUMER, *files]:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, root / path)
            deployments = {CASE_MISSION: CASE_DEPLOYMENT}
            consumer = root / CASE_CONSUMER
            original = consumer.read_text()
            consumer.write_text(original + "\n# Unrelated gameplay maintenance; no change to case placement.\n")
            self.assertEqual(_verify_custody_case(root, deployments)["verified_files"], 10)
            consumer.write_text(original.replace("custody_case_scene.instantiate()", "other_scene.instantiate()"))
            with self.assertRaisesRegex(ValueError, "consumer does not instantiate"):
                _verify_custody_case(root, deployments)
            consumer.write_text(original)
            scene = root / CASE_DEPLOYMENT
            scene.write_text("\n".join(line for line in scene.read_text().splitlines()
                                       if not line.startswith("custody_case_scene =")))
            with self.assertRaisesRegex(ValueError, "does not select the reviewed case"):
                _verify_custody_case(root, deployments)
            with self.assertRaisesRegex(ValueError, "reviewed deployment scene is not registered"):
                _verify_custody_case(root, {CASE_MISSION: CASE_BASE})

    @staticmethod
    def _cut_fixture(root: Path) -> dict:
        # No PASS fixture: the only approval copied is the real historical receipt.
        for relative in (CUT_KIT.receipt, CUT_KIT.battlefield):
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        host = root / CUT_KIT.battlefield
        host.write_bytes(host.read_bytes() + b"\n; test-only unapproved host change\n")
        files = json.loads((root / CUT_KIT.receipt).read_text())["files"]
        return {
            "result": "REWORK",
            "continuity": {
                "previous_receipt": CUT_KIT.receipt,
                "previous_receipt_sha256": CUT_ORIGINAL_RECEIPT_SHA256,
                "battlefield": CUT_KIT.battlefield,
                "previous_battlefield_sha256": files[CUT_KIT.battlefield],
            },
            "evidence": {"continuity": "Test-only description; not a review or an approval."},
            "files": files | {CUT_KIT.battlefield: hashlib.sha256(host.read_bytes()).hexdigest()},
        }

    @staticmethod
    def _write_cut_candidate(root: Path, document: dict) -> str:
        payload = json.dumps(document).encode()
        (root / CUT_CONTINUITY_RECEIPT).write_bytes(payload)
        return hashlib.sha256(payload).hexdigest()

    def test_changed_cut_host_requires_review_pin_and_immutable_original(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            document = self._cut_fixture(root)
            pin = self._write_cut_candidate(root, document)
            with patch("tools.report_deployment_art.CUT_CONTINUITY_RECEIPT_SHA256", None):
                with self.assertRaisesRegex(ValueError, "no pinned continuity review"):
                    _verify_kit(root, CUT_KIT)
            (root / CUT_KIT.receipt).write_bytes((root / CUT_KIT.receipt).read_bytes() + b"\n")
            with patch("tools.report_deployment_art.CUT_CONTINUITY_RECEIPT_SHA256", pin):
                with self.assertRaisesRegex(ValueError, "receipt bytes do not match the pinned review"):
                    _verify_kit(root, CUT_KIT)

    def test_cut_continuation_rejects_wrong_scope_or_payload(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for case, reason in [
                ("wrong context", "does not anchor the original Cut placement"),
                ("missing scope evidence", "evidence.continuity must be recorded"),
                ("reapproved durable", "may replace only the reviewed host digest"),
                ("stale host", "differs from the exact continuity review host"),
                ("unrelated payload", "may replace only the reviewed host digest"),
            ]:
                document = self._cut_fixture(root)
                if case == "wrong context":
                    document["continuity"]["battlefield"] = KITS[0].battlefield
                elif case == "missing scope evidence":
                    document["evidence"].clear()
                elif case == "reapproved durable":
                    document["files"][CUT_KIT.asset] = "a" * 64
                elif case == "stale host":
                    document["files"][CUT_KIT.battlefield] = "b" * 64
                else:
                    document["files"]["assets/unrelated.glb"] = "c" * 64
                pin = self._write_cut_candidate(root, document)
                with self.subTest(case=case), patch("tools.report_deployment_art.CUT_CONTINUITY_RECEIPT_SHA256", pin):
                    with self.assertRaisesRegex(ValueError, reason):
                        _verify_kit(root, CUT_KIT)

    def test_cut_continuation_still_requires_full_pass_and_exact_new_receipt(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            document = self._cut_fixture(root)
            document["schema_version"] = 1
            pin = self._write_cut_candidate(root, document)
            with patch("tools.report_deployment_art.CUT_CONTINUITY_RECEIPT_SHA256", pin):
                with self.assertRaisesRegex(ValueError, "must record an overall PASS"):
                    _verify_kit(root, CUT_KIT)
                (root / CUT_CONTINUITY_RECEIPT).write_bytes(b"{}")
                with self.assertRaisesRegex(ValueError, "receipt bytes do not match the pinned review"):
                    _verify_kit(root, CUT_KIT)
