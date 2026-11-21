# Check a visual audit receipt before publication

Use this optional local check **after independent visual review** in the [visual asset quality gate](asset-quality-gate.md), while the candidate is still outside the repository. It only checks the recorded decision, required fields, and file bytes. A successful run does not assess craft, authenticate a reviewer, open the evidence, or replace review in Godot.

With Python 3.10 or later, run:

```sh
python3 tools/check_visual_audit_receipt.py /path/to/private-review.json \
  --candidate-root /path/to/candidate \
  --file models/asset.glb --file models/asset.blend --file textures/asset.png
```

Repeat `--file` for every proposed source, export, and dependency the review covers. The receipt file list must match that set exactly. Re-run on the final candidate bytes before publication and again on the delivered files if needed. An exit code of 0 means the receipt and hashes match; an incomplete or different result is rejected. This command is not installed as a local Git hook. Pull requests run the tracked-asset and deployment checks described below.

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

## Check changed art before merging

Run `python3 -B -m tools.check_changed_art --base <base-commit>` in the checked-out proposal. The check matches new or changed **tracked** art payloads under `assets/`, and recognized standalone models, images, fonts, materials, shaders and their sidecars under `game/`, to new or updated exact PASS receipts in `docs/audits/`. Generic scenes and resources under `game/` can also contain nonvisual data, so those paths are not automatically classified as art. Deleted payloads alone do not need a fresh receipt. Adding a file to a Git diff does not substitute for the required private review **before** publication.

The **Verify visual asset receipts** pull-request check runs the same check, validates active reviewed placements, and runs the Python audit tests. It does not grant approval merely by running and does not change branch protection.

This check cannot decide edge cases such as a new placement of unchanged art, material or effects generated only in gameplay scripts, or whether all previously shipped assets pass. Review those in their actual game context. The deployment report tracks the current known scope separately.

## Read-only deployment art report

From the repository root, run `python3 -B -m tools.report_deployment_art` for a JSON inventory of the authored campaigns' registered deployments and shared Godot battlefields. It cross-checks the mission catalog and deployment registry and follows each scene's explicit `battlefield_scene` reference. It recognizes their current authored declaration forms rather than evaluating GDScript.

Every current deployment is recorded as **still uses development art**. The five reviewed map kits are listed only for deployments that use their reviewed battlefield, after verifying their actual scene instances and every receipt-listed file. The sealed Godbridle custody case is approved only for the archived Human escort. The active Greyhollow rescue explicitly disables the case, retains the exact shared Mine field, and does not inherit the old case or Storehouse receipts as approvals for its new context. The V1.1 spillway wheel is listed only for Raska’s Spanwater deployment, after verifying its scene-specific visual binding and eight reviewed files. The stock wheel remains in Ilyra’s active deployment and Neris’s historical feeder prototype. Ilyra’s fixed Beach Relay signal stand is listed only for Two Shorelines, after checking its scene-specific adapter and seven exact reviewed files. A separate fixed Headland Relay receipt applies only to the same registered deployment, verifies its own adapter, editable model, exact Godot imports, and original shared field, and does not extend to the signal effects or shoreline. Mara’s V1 High Quay threshold is verified only on the inherited battlefield variant for that mission, which keeps Ilyra on the original harbor. Its receipt pins the wrapper and shared underlying field. The North Bridge receipt covers both camera models and their exact binding in the registered Grain on Credit mission only. The standalone crossing stays a graybox. Sova’s fixed Vault jambs are verified only in the inherited Year Five field for Sova. The central door, lintel and other deployments of Cairnspine are outside that receipt. Each receipt row names whether its placement is a shared battlefield or a specific mission scene. The Mine Storehouse receipt covers only the works shell and roof in the original archived escort, with the shared field retained. Unit benchmarks and unaudited assets are outside this report. A successful export does not approve a map, verify visual quality, or replace the [visual inventory](visual-audit-inventory.md). If a required reference is missing, the known kit is absent, or its receipt no longer matches, the command emits no partial report and returns a nonzero status.

For a campaign release preflight, run `python3 -B -m tools.report_deployment_art --require-release-ready`. The command exits 2 and lists every deployment that lacks full visual approval (currently all 18); invalid inventory or receipt data exits 1. A verified prop or terrain kit is not a map-wide approval. The check is limited to registered campaign deployments: overworld, menus, and other modes still require their own audits. Use this check before packaging; it does not modify editor or development playtests or the Godot export command.

## Inventory existing visuals in the live opening scene

After importing the project, generate an opening inventory with Godot:

```sh
godot --headless --no-header --script tools/inventory_deployment_visuals.gd > /tmp/torn-opening-art.json
godot --headless --no-header --script tools/inventory_deployment_visuals.gd -- ilyra_coast_survey
```

The command instantiates each registered mission without advancing its gameplay. It lists existing renderable nodes at deployment, including meshes and labels made by startup scripts and hidden originals that remain beside a replacement. Each row gives the node path within the mission, nearest containing scene/import, scene ownership, inherited visibility, shadow-only status, and known direct resource paths. A blank resource list can mean procedural art, not “no art.” Engine-generated names can vary between runs.

This is a starting list, not a list of unique assets, a screenshot audit, or an approval decision. Tree visibility does not mean the camera draws the node. Later spawns, effects and state changes, optional rosters, the overworld, menus, and rendering details outside the reported node types require separate review. For approval, follow the [visual inventory](visual-audit-inventory.md) and inspect the required gameplay states in Godot. The release preflight remains separate.

### Cut cemetery stair continuity

The original V7 receipt and its SHA-256 pin remain unchanged. If a different exterior changes the shared Cut scene, the export rejects the new host until an independent reviewer records a separately pinned `docs/audits/cut-cemetery-stair-v7-continuity.json`. This is a full version 1 receipt for the same six paths: only the exact host scene digest may change. Its `continuity` object records `previous_receipt`, `previous_receipt_sha256`, `battlefield`, and `previous_battlefield_sha256`. Record the scoped scene diff (or exact inverse), native stair traversal and matched camera rechecks under `evidence.continuity`. Pin that exact new receipt only after the review. This check does not authenticate its reviewer or reproduce the evidence; the standard byte verifier is unchanged. It records continuity of the stair placement only, not PASS for the separate exterior or the map.
