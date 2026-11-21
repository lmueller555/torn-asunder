# Existing visual art audit

This inventory tracks visual assets already in Torn Asunder. It is a working review list, not a claim that every existing file has been inspected. See the [quality gate](asset-quality-gate.md) for evidence, revision and publication rules.

- **Pass**: approved for the identified delivery. The only initial passes are the two user-approved infantry references.
- **Rework**: an inspected issue prevents approval. Keep it only in development playtests until replaced or audited again.
- **Blocked**: relevant evidence is missing, so no approval can be granted.
- **Unapproved**: identified but not yet reviewed at the required camera distances and conditions. No release or approved gameplay use.

## Approved reference units

| Asset | In-game evidence |
|---|---|
| [Human Infantry](../assets/models/human_infantry.glb) | User-approved reference. The [Mine integration](https://github.com/lmueller555/torn-asunder/pull/122) has a reproducible 1280 × 720 capture of its existing armor, shield and motion in both campaign cameras. |
| [Human Heavy Infantry](../assets/models/human_heavy_infantry.glb) | User-approved reference. The [unit workflow](unit-art-workflow.md) records construction, painted materials, readable silhouette and rig-fit evidence. |

## Approved Mine entrance

The [V10 audit receipt](audits/mine-timber-portal-v10.json) passes the front Mine timber portal and connected stone shoulders in the large Mine scene. It covers the exact reviewed files, both gameplay cameras, close and reverse views, and the detail-to-distance transition. The evacuation arch, mountain, nearby buildings, and other props remain unapproved. The technical result is a scene-relative asset budget, not a console frame-rate benchmark.

## Inspected: first Mine pass

The starting hero and tactical views from the [Mine integration](https://github.com/lmueller555/torn-asunder/pull/122) give a matched baseline. These are individual decisions about what is visible in those views, not verdicts on every reference hidden elsewhere on the map.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Mara’s campaign body](../game/battlefield/command_harness.gd) | Rework | Single-color block construction, no facial or costume silhouette, and no modeled equipment and locomotion comparable to the approved infantry alongside her. |
| [Mine Archer formation](../game/battlefield/command_harness.gd) | Rework | Repeated torsos and equipment proxies do not read as archers. At tactical scale only the marker color and label identify the formation. Scope any eventual model and animation review separately from combat. |
| [Mine approach cliff and ridge surfaces](../game/battlefields/year_one_mine_campaign.tscn) | Rework | From hero view the visible rock faces read as broad, flat color planes with little layering or material separation; the tactical view loses definition between cliff and raised shelf. Keep traversal and cover footprints when replacing the visible surfaces. |
| [Mine approach building and roadside blocks](../game/battlefields/year_one_mine_campaign.tscn) | Rework | Broad flat faces and abrupt untrimmed edges read as volumes, not timber and stone construction; the approach has no worn edges or contact detail at hero distance. Review distinct prop placements separately from terrain. |

## Inspected: Still Kingdom Cut and Cairnspine Boundary Post

Reviewed 1280 × 720 Godot 4.7.2 hero and command views, using the [Cut preview](../tests/still_kingdom_cut_preview.tscn) and [Boundary Post playtest](../game/battlefield/sereth_pass_writ_playtest.tscn). The representative scenes use internal flat-color meshes; terrain-route tests do not establish art performance on target hardware. No row is a pass.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Cut river and crags](../game/battlefields/still_kingdom_cut.tscn) | Rework | Repeated capped crag silhouettes and a flat river color abruptly meeting the bank. The road and blue foot lane are visually close to the water surface. |
| [Cut cemetery stair and retaining walls](../game/battlefields/still_kingdom_cut.tscn) | Rework | At hero height, line markings on the ramp read as drawn seams rather than stone treads. Walls lack courses, caps, and grounded joints. Preserve the smooth collision grade while rebuilding the visible kit. |
| [Cut village shells and record-room exterior](../game/battlefields/still_kingdom_cut.tscn) | Rework | Repeated box silhouettes and blank roof decks do not distinguish the record room or its approach in the command view. |
| [Cut interior record-room and small cemetery props](../game/battlefields/still_kingdom_cut.tscn) | Blocked | No representative hero close-ups for benches, shelving, graves, or document props in this audit. |
| [Boundary Post road, trench and banks](../game/battlefields/cairnspine_boundary_post.tscn) | Rework | Unbroken flat road strips, vertical plane cuts and repeated faceted banks look like route diagrams, not worn terrain and retaining structures. |
| [Boundary Post shelter, low walls and posts](../game/battlefields/cairnspine_boundary_post.tscn) | Rework | The plain roof slab, bare wall volumes and posts give the handover place no identity without its debug label and ring. |
| [Boundary Post small lookout/rally props](../game/battlefields/cairnspine_boundary_post.tscn) | Blocked | Separate hero-scale checks are needed for the lookout sign and rally marker. |

## Inspected: water routes and upland approaches

These rework decisions cover the families visible in the linked Godot previews at representative camera distances. They are not a sign-off on unobserved surfaces, motion, or hardware cost.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Isolated Grove loading yard, tree proxy and raised road](../tests/isolated_grove_nursery_preview.tscn) | Rework | The tree reads as a single canopy cone on a root sphere and flat board. The raised road and screening banks are untextured wedges, with no believable junction between the yard, track and earth. |
| [Red Basin road, wash, cover and roadside shells](../tests/red_basin_well_road_preview.tscn) | Rework | The broad salt road and angular wash read as differently colored ribbons, not different surfaces. Repeated capped cliffs and roof blocks have no erosion, material breakup or construction at hero distance. |
| [Cairnspine Vault Road shelf, cliff faces and forecourt](../tests/cairnspine_vault_road_preview.tscn) | Rework | Bare vertical faces and uniform slabs make the shelf and retaining masonry read as cut geometry. At command distance the terrace and enclosure rely on color blocks rather than recognizable structures. |
| [Moonwash harbor quays and hull silhouettes](../tests/moonwash_harbor_campaign_preview.tscn) | Rework | Walls, stairs, deck and hull are solid planes; the quay edge has no coursework, wear or height transition, and the boats read as colored deck outlines. Review rig and hull materials in the full rescue separately. |
| [Moonwash Survey Shore beach, shoal and signal structure](../tests/moonwash_survey_shore_preview.tscn) | Rework | Hard-edged bands and angular surf stripes read as depth markers. The plain post and ramp do not distinguish a working signal station at hero height. Keep the two headland occlusions and beach/high route distinction in later art. |
| [Spanwater main channel, spillway and wheel stand](../tests/spanwater_lock_campaign_preview.tscn) | Rework | The channel and spilling water are solid color planes and square masses. The wheel is recognizable but its block stand, gates and banks lack construction or believable joins. Moving water cues and the two layouts still need separate in-game checks. |

## Existing art awaiting individual review

Use one audit per shared asset or kit, with every distinct gameplay use recorded. Split these rows into individual records as the assets are inspected. Do not infer a pass or fail from an unreviewed row.

| Scope | Status | Start here |
|---|---|---|
| Remaining Mine props, artifact, guard and alternate hero / unit visuals | Unapproved | [Both Mine layouts](../game/battlefields/) and [escort visual code](../game/battlefield/mara_mine_escort.gd). Check the artifact while on the ground and carried; review each non-benchmark character silhouette. |
| Marches crossing and remaining Red Basin assets | Unapproved | [Crossing](../game/battlefields/marches_crossing.tscn) and [well road](../game/battlefields/red_basin_well_road.tscn). Inspect the crossing and its bridge/ford; confirm the Red Basin carts, well hardware and outlying buildings in actual missions. |
| Remaining Moonwash harbor and survey shore families | Unapproved | [Harbor](../game/battlefields/moonwash_harbor_campaign.tscn) and [survey shore](../game/battlefields/moonwash_survey_shore.tscn). Review water, shoreline, quays, rigs, boats, signals and character visuals independently. |
| Remaining Spanwater Lock and nursery families | Unapproved | [Lock](../game/battlefields/spanwater_lock_campaign.tscn) and [grove](../game/battlefields/isolated_grove_nursery.tscn). Review both lock layouts, water channels and control props, then the nursery, sled, tree and supporting figures. |
| Remaining Cairnspine Vault Road and Cut/Boundary families | Unapproved | [Vault Road](../game/battlefields/cairnspine_vault_road.tscn). Review its settlement and route materials, landmarks, and uninspected non-benchmark character art across the three locations. |
| Vareth overworld | Unapproved | [Current board](../game/campaign_map_board.gd) is a development view. Check its art separately from waypoint and travel logic; the replacement must preserve route and pin readability at ordinary view and close zoom, including locked and unlocked states on the camp-to-Mine path. |
| Other existing UI art and portraits | Unapproved | [Art resources](../assets/art/). These are not terrain, but are not among the user-approved reference assets. Audit in their actual UI context. |
