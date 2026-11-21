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

## Approved Mine assets

The [V10 audit receipt](audits/mine-timber-portal-v10.json) passes the front Mine timber portal and connected stone shoulders in the large Mine scene. It covers the exact reviewed files, both gameplay cameras, close and reverse views, and the detail-to-distance transition. The evacuation arch, mountain, nearby buildings, and other props remain unapproved. The technical result is a scene-relative asset budget, not a console frame-rate benchmark.

The [V3 audit receipt](audits/godbridle-custody-case-v3.json) passes the sealed Godbridle case only in Mara’s campaign Mine. The case replaces the old exposed symbolic bridle in those ground and carry states, keeps the pickup and navigation cues, and does not replace any other mission’s artifact art.

## Inspected: first Mine pass

The starting hero and tactical views from the [Mine integration](https://github.com/lmueller555/torn-asunder/pull/122) give a matched baseline. These are individual decisions about what is visible in those views, not verdicts on every reference hidden elsewhere on the map.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Mara’s campaign body](../game/battlefield/command_harness.gd) | Rework | Single-color block construction, no facial or costume silhouette, and no modeled equipment and locomotion comparable to the approved infantry alongside her. |
| [Mine Archer formation](../game/battlefield/command_harness.gd) | Rework | Repeated torsos and equipment proxies do not read as archers. At tactical scale only the marker color and label identify the formation. Scope any eventual model and animation review separately from combat. |
| [Mine approach cliff and ridge surfaces](../game/battlefields/year_one_mine_campaign.tscn) | Rework | From hero view the visible rock faces read as broad, flat color planes with little layering or material separation; the tactical view loses definition between cliff and raised shelf. Keep traversal and cover footprints when replacing the visible surfaces. |
| [Mine approach building and roadside blocks](../game/battlefields/year_one_mine_campaign.tscn) | Rework | Broad flat faces and abrupt untrimmed edges read as volumes, not timber and stone construction; the approach has no worn edges or contact detail at hero distance. Review distinct prop placements separately from terrain. |

## Inspected: Still Kingdom Cut and Cairnspine Boundary Post

Reviewed 1280 × 720 Godot 4.7.2 hero and command views, using the [Cut preview](../tests/still_kingdom_cut_preview.tscn) and [Boundary Post playtest](../game/battlefield/sereth_pass_writ_playtest.tscn). The representative scenes use internal flat-color meshes; terrain-route tests do not establish art performance on target hardware. Only the independently audited placements listed as Pass below are approved.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Cut river and crags](../game/battlefields/still_kingdom_cut.tscn) | Rework | Repeated capped crag silhouettes and a flat river color abruptly meeting the bank. The road and blue foot lane are visually close to the water surface. |
| [Cut cemetery stair, retaining walls and footing](audits/cut-cemetery-stair-v7.json) | Pass | The exact V7 S3TC kit replaces the old ramp appearance without changing its collision grade. Verified during actual ascent and from both cameras. The [continuity review](audits/cut-cemetery-stair-v7-continuity.json) preserves the same exact placement in the current shared scene. Scene-relative rendering and memory evidence, not a hardware frame-rate claim. |
| [Cut Record Room exterior](audits/cut-record-room-v31.json) | Pass | V3.1 passes only the modeled stone entrance, timber header, sign, eave and exterior walls of this placement. Native hero and command views, doorway movement, roof picking and the exact LOD transition were checked; no hardware frame-rate claim. |
| [Other Cut village shells](../game/battlefields/still_kingdom_cut.tscn) | Rework | Repeated box silhouettes and blank roof decks remain unapproved around the audited Record Room. |
| [Cut interior record-room and small cemetery props](../game/battlefields/still_kingdom_cut.tscn) | Blocked | No representative hero close-ups for benches, shelving, graves, or document props in this audit. |
| [Boundary Post road, trench and banks](../game/battlefields/cairnspine_boundary_post.tscn) | Rework | Unbroken flat road strips, vertical plane cuts and repeated faceted banks look like route diagrams, not worn terrain and retaining structures. |
| [Boundary Post open-front Keeper shelter](audits/keeper-boundary-shelter-v11.json) | Pass | Exact V1.1 ashlar support, timber and slate in the [live writ deployment](../game/battlefield/sereth_pass_writ_playtest.tscn). The stock open front, actual exterior handover and roof collision remain. Hero and command distances and scene-relative cost verified. The bench, Keeper, writ and surrounding field are outside this approval. |
| [Boundary Post low walls and other posts](../game/battlefields/cairnspine_boundary_post.tscn) | Rework | Plain blocks in the reviewed tactical and hero frames lack finished construction and distinct silhouettes. Keep the existing sight breaks. |
| [Boundary Post small lookout/rally props](../game/battlefields/cairnspine_boundary_post.tscn) | Blocked | Separate hero-scale checks are needed for the lookout sign and rally marker. |

## Inspected: Marches Crossing

Reviewed from the live [Grain on Credit deployment](../game/battlefield/mara_grain_crossing_playtest.tscn) on both crossings, in hero view, local tactical view and full overview.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [North timber bridge and footings](../game/battlefields/marches_crossing.tscn) | Rework | The repeating square parts and uniform deck read as placeholders at hero height. Preserve the actual walked deck, solid rails and exposed sightline. |
| [South ford shallows and crossing stones](../game/battlefields/marches_crossing.tscn) | Rework | A flat pale band marks the walkable lane but reads as a glowing tile rather than a shallow river bed. Preserve the supported shelf, slower cart crossing, deep-channel barriers and screened approach. |
| [Channel edges and adjacent valley landform](../game/battlefields/marches_crossing.tscn) | Rework | The angular blue strip, sharp bank seams, disconnected-looking roads and stacked perimeter walls read as a diagram at tactical distance. Keep the open bridge route distinct from the covered ford. |

The rival reserve can physically block either lane. Preserve that route choice, cart clearance and the named crossing and reserve cues; the current oversized floating labels can obscure the hero’s approach. Roadside props and outlying buildings still need their own review.

## Inspected: water routes and upland approaches

These rework decisions cover the families visible in the linked Godot previews at representative camera distances. They are not a sign-off on unobserved surfaces, motion, or hardware cost.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Isolated Grove loading yard, tree proxy and raised road](../tests/isolated_grove_nursery_preview.tscn) | Rework | The tree reads as a single canopy cone on a root sphere and flat board. The raised road and screening banks are untextured wedges, with no believable junction between the yard, track and earth. |
| [Red Basin road, wash, cover and roadside shells](../tests/red_basin_well_road_preview.tscn) | Rework | The broad salt road and angular wash read as differently colored ribbons, not different surfaces. Repeated capped cliffs and roof blocks have no erosion, material breakup or construction at hero distance. |
| [Cairnspine Vault Road shelf, cliff faces and forecourt](../tests/cairnspine_vault_road_preview.tscn) | Rework | Bare vertical faces and uniform slabs make the shelf and retaining masonry read as cut geometry. At command distance the terrace and enclosure rely on color blocks rather than recognizable structures. |
| [Moonwash harbor quays and hull silhouettes](../tests/moonwash_harbor_campaign_preview.tscn) | Rework | Walls, stairs, deck and hull are solid planes; the quay edge has no coursework, wear or height transition, and the boats read as colored deck outlines. Review rig and hull materials in the full rescue separately. |
| [Moonwash Survey Shore beach, shoal and signal structure](../tests/moonwash_survey_shore_preview.tscn) | Rework | Hard-edged bands and angular surf stripes read as depth markers. The plain post and ramp do not distinguish a working signal station at hero height. Keep the two headland occlusions and beach/high route distinction in later art. |
| [Ilyra’s fixed Beach Relay signal stand](audits/ilyra-beach-signal-stand-v1.json) | Pass | Exact V1 stone foot, timber mast, metal straps, rope and fixed pennant only in Two Shorelines. Both stock solids, markers and line of sight remain. Native hero and tactical views, actual contested and transmitting states, and scene-relative cost verified. Headland, shore, signal effects and surrounding actors remain unapproved. |
| [Spanwater main channel and spillway terrain](../tests/spanwater_lock_campaign_preview.tscn) | Rework | Channel and spilling water are solid color planes and the old gates and banks lack believable joins. Moving water cues and the two layouts still need separate in-game checks. The stock wheel remains unapproved in the other uses. |
| [Raska's spillway wheel, axle and stand](audits/raska-spanwater-wheel-v11.json) | Pass | Exact V1.1 only in River, Not Sea. Native hero before and after the real release plus tactical and overview, exact collision and scene-relative cost verified. Ilyra's and Neris's existing visuals, water, actors and the rest of the field are outside this approval. |

## Inspected: Red Basin lower storehouse

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Lower storehouse exterior](audits/red-basin-storehouse-v12.json) | Pass | Exact V1.2 closed shutter, walls, stone base and roof in [The Second Bucket](../game/battlefield/raska_well_road_playtest.tscn). Native hero and tactical views, the exterior action point and real cart arrival were checked. This is a single-placement approval with scene-relative rendering measurements. |

The hero starts boarding at the exterior storehouse ring, not at either well. Keep the building solid and closed, its roof blocked to command targeting, and the cart’s separate approach to the yard clear. After the cart arrives, the three households must physically reach it before the cart is ready. The building review does not cover the wells, bench, wagons, households or cliffs.

## Inspected: Ilyra’s live Moonwash rescue

Reviewed in hero, local tactical and overview views of [Hulls on Stone](../game/battlefield/ilyra_moonwash_rescue_campaign.tscn), not just the [shared harbor preview](../tests/moonwash_harbor_campaign_preview.tscn). The two transfer decks share the battlefield scene with Mara’s High Quay; this does not audit her view of the quay or every surrounding hull.

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Receiving and stranded ships](../game/battlefields/moonwash_harbor_campaign.tscn) | Rework | The two hulls read as long colored slabs. Flat deck fills and bare cross-shaped masts lack built planking, rail joins, bulwarks or visible working rigging. Preserve each vessel’s distinct deck elevation and the two independent receiving positions. |
| [Pier and boarding gangways](../game/battlefields/moonwash_harbor_campaign.tscn) | Rework | Broad stepped blocks lack timber joints and look like incidental terrain rather than a supported access route. Keep the actual receiving gangway, pier turns, open mooring and climb to the stranded deck fully traversable. |
| [Fore and aft transfer visuals](../game/battlefield/ilyra_moonwash_rescue_campaign.gd) | Rework | The placed spans are plain strips with thin colored lines; their attachment and safe walkway are difficult to see from Ilyra’s rig view, where large labels dominate. Keep state-dependent visibility, both route positions, independent rigging and clear fore-contested versus aft-open feedback. |
| [Crews and shore salvagers](../game/battlefield/ilyra_moonwash_rescue_campaign.gd) | Rework | Unanimated grouped box figures and floating names do not read as crews walking a rescue span. Preserve each party’s boarding order, independent position, and the visible actual salvager approach. |

Both decks were reached on the authored pier route. Rigging the fore transfer brought the salvagers to the mooring and paused the fore party. The aft crew landed independently; a Shore Marine Hold then allowed the fore crew to land. The optional cargo visual and the alternate approach contexts still need their own review.

## Inspected: Vareth overworld

| Existing asset or family | Status | What blocks a pass |
|---|---|---|
| [Vareth campaign board](../game/campaign_map_board.gd) | Rework | Native Godot captures on Mara’s and Ilyra’s routes show the same flat schematic terrain: repeated peak silhouettes, angular river and coastline, and no authored settlement or shoreline detail. The flat board still shrinks at a smaller window rather than providing real zoom. The live board’s route cue now highlights only a reachable selected leg, and its lower labels clear the frame and party badge; these interaction fixes do not approve the terrain. |

Keep the current-location marker distinct from selection; keep explicit lock icons and reasons, travel separate from deployment, and mouse, keyboard and controller input. Audit the 3D replacement in the live campaign shell at ordinary view and real close zoom, including locked, available and in-transit states. These observations apply to the existing board, not to an unmerged art candidate.

## Existing art awaiting individual review

Use one audit per shared asset or kit, with every distinct gameplay use recorded. Split these rows into individual records as the assets are inspected. Do not infer a pass or fail from an unreviewed row.

| Scope | Status | Start here |
|---|---|---|
| Remaining Mine props, other artifact depictions, guard and alternate hero / unit visuals | Unapproved | [Both Mine layouts](../game/battlefields/) and [escort visual code](../game/battlefield/mara_mine_escort.gd). Review remaining artifact depictions at their actual in-game placements and check each non-benchmark character silhouette. |
| Remaining Marches and Red Basin assets | Unapproved | [Crossing](../game/battlefields/marches_crossing.tscn) and [well road](../game/battlefields/red_basin_well_road.tscn). Inspect carts, well hardware, roadside props and outlying buildings in actual missions. |
| Remaining Moonwash harbor and survey shore families | Unapproved | [Harbor](../game/battlefields/moonwash_harbor_campaign.tscn) and [survey shore](../game/battlefields/moonwash_survey_shore.tscn). Review water, shoreline, quays, rigs, boats, signals and character visuals independently. |
| Remaining Spanwater Lock and nursery families | Unapproved | [Lock](../game/battlefields/spanwater_lock_campaign.tscn) and [grove](../game/battlefields/isolated_grove_nursery.tscn). Review both lock layouts, water channels and control props, then the nursery, sled, tree and supporting figures. |
| Remaining Cairnspine Vault Road and Cut/Boundary families | Unapproved | [Vault Road](../game/battlefields/cairnspine_vault_road.tscn). Review its settlement and route materials, landmarks, and uninspected non-benchmark character art across the three locations. |
| Other existing UI art and portraits | Unapproved | [Art resources](../assets/art/). These are not terrain, but are not among the user-approved reference assets. Audit in their actual UI context. |
