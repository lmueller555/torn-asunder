"""A changed payload cannot borrow contradictory or stale visual review."""

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools.check_changed_art import check_changed_art

ROOT = Path(__file__).resolve().parents[1]
RECEIPT = "docs/audits/red-basin-storehouse-v12.json"
CONTENT = json.loads((ROOT / RECEIPT).read_text(encoding="utf-8"))["files"]
ART = {path for path in CONTENT if path.startswith("assets/")}


class ChangedArtTest(unittest.TestCase):
    def test_exact_real_reviewed_payload_can_pass(self):
        self.assertEqual(check_changed_art(ROOT, [*CONTENT, RECEIPT]), ART)

    def test_authored_assets_without_updated_receipt_fail_even_when_already_reviewed(self):
        for path in [
            "assets/art/New asset.PNG",
            "assets/models/terrain.gdshader",
            "game/battlefield/demo.gdshader",
            "game/battlefield/demo.gdshader.uid",
            "game/battlefield/silt.gdshaderinc",
            "game/battlefield/props/signal.glb",
            "game/battlefield/props/signal.glb.import",
            "game/battlefield/props/timber.material",
            "game/menu/portrait.PNG.import",
            "game/menu/campaign.svg",
            "game/menu/readout.woff2",
            "assets/models/example.gd.uid",
            "assets/art/portrait.webp.import",
            "assets/source/source.blend",
            *ART,
        ]:
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "no new or updated exact PASS"):
                check_changed_art(ROOT, [path])

    def test_traversal_and_docs_are_not_visual_payloads(self):
        paths = [
            "docs/controls.md", "game/campaign_world.gd", "game/menu/campaign.tscn",
            "game/battlefield/mission_data.tres", "tests/foo.tscn", "tests/studio_test.gdshader",
        ]
        self.assertEqual(check_changed_art(ROOT, paths), set())

    def test_scene_local_visual_payload_passes_with_its_exact_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            receipt = root / RECEIPT
            receipt.parent.mkdir(parents=True)
            sample = next(path for path in ART if path.endswith(".glb"))
            path = "game/battlefield/props/sample.glb"
            model = root / path
            model.parent.mkdir(parents=True)
            shutil.copyfile(ROOT / sample, model)
            review = json.loads((ROOT / RECEIPT).read_text(encoding="utf-8"))
            review["files"] = {path: CONTENT[sample]}
            receipt.write_text(json.dumps(review), encoding="utf-8")
            self.assertEqual(check_changed_art(root, [path, RECEIPT]), {path})

    def test_reworked_or_stale_receipts_do_not_cover_payloads(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in [*CONTENT, RECEIPT]:
                destination = root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, destination)
            reviewer = json.loads((root / RECEIPT).read_text(encoding="utf-8"))
            reviewer["result"] = "REWORK"
            (root / RECEIPT).write_text(json.dumps(reviewer), encoding="utf-8")
            path = next(path for path in ART if path.endswith(".glb"))
            with self.assertRaisesRegex(ValueError, "overall PASS"):
                check_changed_art(root, [path, RECEIPT])
            shutil.copyfile(ROOT / RECEIPT, root / RECEIPT)
            with (root / path).open("ab") as stream:
                stream.write(b"not the reviewed bytes")
            with self.assertRaisesRegex(ValueError, "SHA-256 differs"):
                check_changed_art(root, [path, RECEIPT])
