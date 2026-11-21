"""Synthetic temporary inputs only; none of these receipts is an art approval."""

from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from tools.check_visual_audit_receipt import main, verify_receipt


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        scratch = TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name) / "candidate"
        self.root.mkdir()
        self.record = Path(scratch.name) / "synthetic-test-record.json"
        self.files = {"asset.glb": b"synthetic export bytes", "art/surface.png": b"synthetic dependency bytes"}
        for name, data in self.files.items():
            path = self.root / name
            path.parent.mkdir(exist_ok=True)
            path.write_bytes(data)
        self.receipt = {
            "schema_version": 1,
            "scope": "Synthetic test fixture only",
            "author": "Fixture Author",
            "reviewer": "Fixture Reviewer",
            "reviewed_on": datetime.now(timezone.utc).date().isoformat(),
            "result": "PASS",
            "evidence": {
                "godot_context": "synthetic context reference",
                "close_up": "synthetic close-up reference",
                "reproduction": "synthetic reproduction reference",
                "measurements": "synthetic measurements reference",
            },
            "checks": {
                "shape_and_craft": {"result": "PASS"},
                "materials_and_lighting": {"result": "PASS"},
                "readability_in_play": {"result": "PASS"},
                "integration_and_cost": {"result": "PASS"},
                "motion_and_effects": {"result": "NOT_APPLICABLE", "reason": "This fixture has no moving parts"},
            },
            "files": {name: hashlib.sha256(data).hexdigest() for name, data in self.files.items()},
        }

    def write_record(self):
        self.record.write_text(json.dumps(self.receipt), encoding="utf-8")

    def verify(self, proposed=None):
        self.write_record()
        return verify_receipt(self.record, self.root, list(self.files) if proposed is None else proposed)

    def test_pass_requires_the_exact_set_and_bytes(self):
        self.assertEqual(self.verify(list(reversed(list(self.files)))), 2)
        for proposed in [[], ["asset.glb"], ["asset.glb", "asset.glb"], [*self.files, "unlisted.glb"]]:
            with self.subTest(proposed=proposed), self.assertRaises(ValueError):
                self.verify(proposed)
        (self.root / "art/surface.png").write_bytes(b"synthetic dependency was revised")
        with self.assertRaisesRegex(ValueError, "SHA-256 differs"):
            self.verify()

    def test_missing_file_or_malformed_digest_is_rejected(self):
        (self.root / "asset.glb").unlink()
        with self.assertRaises(FileNotFoundError):
            self.verify()
        (self.root / "asset.glb").write_bytes(self.files["asset.glb"])
        self.receipt["files"]["asset.glb"] = "badly formatted hash"
        with self.assertRaisesRegex(ValueError, "expected a lowercase SHA-256"):
            self.verify()

    def test_missing_or_nonpassing_decisions_are_rejected(self):
        for decision in [None, "", "BLOCKED", "REWORK", "NOT_REVIEWED"]:
            self.receipt["result"] = decision
            with self.subTest(decision=decision), self.assertRaisesRegex(ValueError, "overall PASS"):
                self.verify()
        self.receipt["result"] = "PASS"
        del self.receipt["checks"]["shape_and_craft"]
        with self.assertRaisesRegex(ValueError, "every gate category"):
            self.verify()
        self.receipt["checks"]["shape_and_craft"] = {"result": "REWORK"}
        with self.assertRaisesRegex(ValueError, "shape_and_craft is not approved"):
            self.verify()

    def test_reviewer_must_be_named_and_not_author(self):
        for reviewer in ["", "Pending", None, "  fiXture   Author  "]:
            self.receipt["reviewer"] = reviewer
            with self.subTest(reviewer=reviewer), self.assertRaisesRegex(ValueError, "reviewer must"):
                self.verify()

    def test_review_date_must_exist_be_iso_and_not_future(self):
        for reviewed_on in ["", "20261101", "2026-02-30", (datetime.now(timezone.utc).date() + timedelta(days=1)).isoformat()]:
            self.receipt["reviewed_on"] = reviewed_on
            with self.subTest(reviewed_on=reviewed_on), self.assertRaises(ValueError):
                self.verify()

    def test_utc_review_date_does_not_depend_on_workstation_day(self):
        self.receipt["reviewed_on"] = "2026-11-21"
        utc_midnight = datetime(2026, 11, 21, 0, 15, tzinfo=timezone.utc)
        with patch("tools.check_visual_audit_receipt.datetime") as clock:
            clock.now.return_value = utc_midnight
            self.assertEqual(self.verify(), len(self.files))
            clock.now.assert_called_once_with(timezone.utc)


    def test_evidence_types_and_motion_result(self):
        context = self.receipt["evidence"].pop("godot_context")
        with self.assertRaisesRegex(ValueError, "godot_context"):
            self.verify()
        self.receipt["evidence"]["godot_context"] = context
        self.receipt["checks"]["motion_and_effects"] = {"result": "PASS"}
        with self.assertRaisesRegex(ValueError, "evidence.motion"):
            self.verify()
        self.receipt["evidence"]["motion"] = "synthetic video reference"
        self.assertEqual(self.verify(), 2)
        self.receipt["checks"]["motion_and_effects"] = {"result": "NOT_APPLICABLE", "reason": "TBD"}
        with self.assertRaisesRegex(ValueError, "motion_and_effects.reason"):
            self.verify()
        self.receipt["checks"]["integration_and_cost"] = {"result": "NOT_APPLICABLE", "reason": "not tested"}
        with self.assertRaisesRegex(ValueError, "integration_and_cost is not approved"):
            self.verify()

    def test_ambiguous_and_outside_paths_are_rejected(self):
        for invalid in ["../asset.glb", "/asset.glb", "./asset.glb", "art//surface.png", "C:/asset.glb", "art\\surface.png"]:
            self.receipt["files"] = {invalid: hashlib.sha256(b"file").hexdigest()}
            with self.subTest(invalid=invalid), self.assertRaisesRegex(ValueError, "canonical relative file path"):
                self.verify([invalid])

    def test_symlink_is_not_a_regular_proposed_file(self):
        path = self.root / "asset.glb"
        path.unlink()
        outside = self.root.parent / "outside.glb"
        outside.write_bytes(self.files["asset.glb"])
        try:
            path.symlink_to(outside)
        except OSError as error:
            self.skipTest(str(error))
        with self.assertRaisesRegex(ValueError, "non-symlink file"):
            self.verify()

    def test_duplicate_keys_are_rejected(self):
        self.write_record()
        self.record.write_text(self.record.read_text(encoding="utf-8").replace(
            '"result": "PASS", "evidence":', '"result": "REWORK", "result": "PASS", "evidence":', 1), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "duplicate receipt key: result"):
            verify_receipt(self.record, self.root, list(self.files))

    def test_cli_is_explicit_and_never_claims_visual_approval(self):
        arguments = [str(self.record), "--candidate-root", str(self.root), "--file", "asset.glb", "--file", "art/surface.png"]
        self.write_record()
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(main(arguments), 0)
        self.assertIn("does not assess or approve visual quality", output.getvalue())
        self.receipt["result"] = "REWORK"
        self.write_record()
        error = io.StringIO()
        with redirect_stderr(error), redirect_stdout(io.StringIO()) as output:
            self.assertEqual(main(arguments), 1)
        self.assertIn("Receipt rejected", error.getvalue())
        self.assertEqual(output.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
