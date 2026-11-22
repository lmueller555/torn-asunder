# Visual asset quality gate

*Torn Asunder* targets the visual finish of a polished PlayStation 3 / Xbox 360 game. Match that level of craft while keeping our own art direction. A triangle count, texture resolution, or offline beauty render cannot establish the standard on its own.

This gate applies to art already in the project as well as to each new or visibly revised unit, prop, environment kit, map layer, material, animation, effect, and UI art asset. Treat a kit as one submission only when its pieces are shown together in the same use case and each proposed piece is inspectable. A new use of an existing asset needs a context check for scale, readability, and performance; that check does not replace auditing any new or changed art.

For a new or revised unit, complete the [unit discovery and animation brief](unit-art-workflow.md#0-research-the-unit-and-plan-its-animation-set) before authoring. A completed brief is not an audit pass.

## Existing art

See the [existing visual art inventory](visual-audit-inventory.md) for confirmed findings and pending reviews.

Human Infantry and Heavy Infantry are the two already-approved benchmarks. Use their finished in-game silhouettes, materials, detail and motion as the visual reference at the corresponding camera distance; do not require unrelated assets to use their mesh or texture budgets.

All other existing map and gameplay art starts **Unapproved**, not grandfathered in. Inventory what actually renders and where; review each existing candidate against the same criteria below. A placeholder that visibly fails is **Rework**; missing evidence is **Blocked**. Neither is eligible for approved gameplay or release. Old grayboxes may remain only in clearly labeled development playtests so the team can keep testing routes and mechanics while replacements are built. Moving an old placeholder to a new mission, renaming it, or generating it at runtime does not make it approved.

## 1. Keep the candidate outside the repository

Build in a local working folder. When necessary, import into a disposable Godot copy to test the actual delivery files. Do not add, commit, upload to a GitHub branch or draft PR, or leave runtime references to unapproved candidate art. Use existing grayboxes for gameplay development; they are not a route around this gate or an approved look for release.

Provide the editable Blender or Godot source, the exact candidate export and its dependencies, intended scale and use, how to reproduce the Godot test, and representative captures. Record SHA-256 digests of the audited deliverable files; if any of those files changes, review the new candidate before publishing it. Agree on a representative camera, lighting, and scene so the author and reviewer evaluate the same evidence.

## 2. Review the actual asset in Godot

A reviewer other than the asset author examines the evidence and checks the candidate in the relevant game view. Use the same camera and lighting for before/after. Include context as well as a close-up; close-up detail alone does not make an asset work at play distance.

| Check | Pass evidence |
|---|---|
| Shape and craft | Strong silhouette, correct proportions and scale, intentional construction and detail, and no visible seams, clipping, floating pieces, or unfinished backside from playable angles. |
| Materials and lighting | Coherent palette, convincing surface response, clean texture detail with no obvious stretching, tiling or lighting artifacts. Check under the lighting the player will see, not only in a studio setup. |
| Readability in play | The player can distinguish important units, objectives, terrain boundaries and interactable points at intended camera distances. Review battlefield art in both hero and command views where applicable. For overworld art, check normal map view, zoomed detail, and waypoint/route legibility. |
| Motion and effects | For moving art, check transitions, contacts, planted feet or supports, timing, repeat behavior and clipping in a short gameplay capture. For effects, ensure the important cue reads and does not obscure controls or targets. |
| Integration and cost | The exact delivery imports cleanly; designed traversal, collision and interaction are preserved. Test repeat instances or the largest relevant view, log measurements and settings, and note the target or baseline used. An untested performance budget is not a pass. |

Mark non-applicable checks with a reason. Record one overall result: **Pass**, **Rework**, or **Blocked**. An unknown or missing required check is **Blocked**, not approved. If visual quality, fit, or technical checks fail, explain what must change, revise locally, and repeat the audit with fresh evidence. There is no limit on revision rounds.

## 3. Publish only the passed candidate

A **Pass** identifies the reviewer, date, exact candidate digests, capture or reproduction references, relevant measurements, and the results above. Only then may the passed files be added to the repository in a focused PR. Include or link the review record in the PR and verify the published files match the audited candidate. Gameplay may use the asset only after it passes. If an import, material, animation, mesh, or other audited file changes before merge, hold the changed version for another review.
