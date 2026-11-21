# Check a visual audit receipt before publication

Use this optional local check **after independent visual review** in the [visual asset quality gate](asset-quality-gate.md), while the candidate is still outside the repository. It only checks the recorded decision, required fields, and file bytes. A successful run does not assess craft, authenticate a reviewer, open the evidence, or replace review in Godot.

With Python 3.10 or later, run:

```sh
python3 tools/check_visual_audit_receipt.py /path/to/private-review.json \
  --candidate-root /path/to/candidate \
  --file models/asset.glb --file models/asset.blend --file textures/asset.png
```

Repeat `--file` for every proposed source, export, and dependency the review covers. The receipt file list must match that set exactly. Re-run on the final candidate bytes before publication and again on the delivered files if needed. An exit code of 0 means the receipt and hashes match; an incomplete or different result is rejected. This check is not installed as a hook or CI step.

## JSON receipt, version 1

| Field | Required value |
| --- | --- |
| `schema_version` | Integer `1`. |
| `scope` | Name and intended in-game use or context. |
| `author`, `reviewer` | Named author and independent reviewer. The checker rejects the same normalized name, but cannot establish independence. |
| `reviewed_on` | Actual UTC review date, `YYYY-MM-DD`, not in the future in UTC. Receipt staleness here means changed files, not elapsed time; a changed in-game use still needs a human context check. |
| `result` | Overall `PASS` as recorded by the reviewer. `REWORK`, `BLOCKED`, unreviewed and missing results cannot pass the checker. |
| `evidence` | References (nonblank strings) under `godot_context`, `close_up`, `reproduction`, and `measurements`. Add `motion` for an applicable motion/effects check. Point to actual Godot play-distance captures, a close-up, reproducible steps/settings, and technical measurements with a target or baseline. Include both hero and command context where applicable. |
| `checks` | Exactly five entries: `shape_and_craft`, `materials_and_lighting`, `readability_in_play`, `motion_and_effects` and `integration_and_cost`. Each is an object with `result`: `PASS` or, where justified, `NOT_APPLICABLE` with a nonblank `reason`. Readability and integration must be `PASS`. |
| `files` | Object mapping each proposed file's canonical root-relative path (forward slashes, no symlinks) to its reviewed 64-digit lowercase SHA-256. |

Keep the unaudited work and private evidence out of the repository. Do not create a placeholder PASS receipt: each field must describe the actual independent review. A hash mismatch needs a new review, not simply a rewritten digest.

## Read-only deployment art report

From the repository root, run `python3 -B -m tools.report_deployment_art` for a JSON inventory of the authored campaigns' registered deployments and shared Godot battlefields. It cross-checks the mission catalog and deployment registry and follows each scene's explicit `battlefield_scene` reference. It recognizes their current authored declaration forms rather than evaluating GDScript.

Every current deployment is recorded as **still uses development art**. The two reviewed map kits are listed only for deployments that use their reviewed battlefield, after verifying their actual scene instances and every receipt-listed file. The sealed Godbridle custody case is listed only for Mara’s Mine deployment, after checking the active mission binding and its ten durable reviewed files. It is not part of the shared Mine terrain. Each receipt row names whether its placement is a shared battlefield or a specific mission scene. Historical case-binding hashes preserve the review record; the report checks today’s binding without requiring unrelated gameplay code to stay byte-identical. Unit benchmarks and unaudited assets are outside this report. A successful export does not approve a map, verify visual quality, or replace the [visual inventory](visual-audit-inventory.md). If a required reference is missing, the known kit is absent, or its receipt no longer matches, the command emits no partial report and returns a nonzero status.

For a campaign release preflight, run `python3 -B -m tools.report_deployment_art --require-release-ready`. The command exits 2 and lists every deployment that lacks full visual approval (currently all 18); invalid inventory or receipt data exits 1. A verified prop or terrain kit is not a map-wide approval. The check is limited to registered campaign deployments: overworld, menus, and other modes still require their own audits. Use this check before packaging; it does not modify editor or development playtests or the Godot export command.
