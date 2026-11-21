# Still Kingdom cut and village: campaign graybox

The [approved V7 S3TC cemetery stair kit](audits/cut-cemetery-stair-v7.json) replaces the old stair visuals, retaining sides, and footing. The [approved V3.1 Record Room exterior](audits/cut-record-room-v31.json) replaces the doorway assembly, exterior walls, slate eave and sign. A [separate context review](audits/cut-cemetery-stair-v7-continuity.json) confirms the new shared scene retains the exact stair art, placement and physical ascent. Routes, cover, objective markers and collision are unchanged. The interior props, surrounding village and rest of the map have not passed the visual audit.

`game/battlefields/still_kingdom_cut.tscn` is the terrain for Sereth's Year Three mission [The Names at the Cut](campaigns/undead.md#1-the-names-at-the-cut--year-three-sereth_voices_at_the_cut). This scene has no living actors, patrols, objective logic, water simulation, voices or apparitions. Iren's and the clerk's positions are placement hooks, not evidence of what the villagers heard.

Run `tests/still_kingdom_cut_preview.tscn` with F6. **1** gives the whole cut, **2** the village sector, and **3** a hero-height view from below the cemetery stairs. The capsules are scale markers only.

```sh
godot tests/still_kingdom_cut_preview.tscn
godot tests/still_kingdom_cut_preview.tscn -- --hero
godot --headless --script tests/still_kingdom_cut.gd
```

## Geography and approach choices

The support plane measures **410 × 248 m**. **+X is east toward the retreat edge, −Z is north**. The village is at Y=0 and the cut at Y=−5. The river tint is visual only.

- **The cut.** Part of the grave bank has collapsed. A narrow, physically raised stair climbs past the cemetery to the upper gate. The cut has a separate recoverable-record site, away from Iren's witness position on higher ground. The stair hold can see the foot of the climb without exposing Iren to the open road.
- **Village and record room.** The walled foot lane doglegs between gates and baffles. It reaches a hollow, roofed record room by the west doorway. The living clerk, place to enter the account, and bundle security point are distinct. A recovery point outside the room and a separate east retreat edge let future rules distinguish losing control, recovering the bundle, and losing it to extraction.
- **Mounted pressure.** The straight, exposed village road reaches the record approach. A north-bank bluff hides the reserve until it rounds the screen and reaches a visible warning point. Solid walls break a direct mounted run through the interior foot lane; they also let a nearby foot party move without being seen from the road. No charge, detection or guaranteed interception is scripted here.

The **normal infantry march** takes **about 130 s over 390 m** between the live mission’s two command limits on the open village road, including the 386 m between the inset road-edge markers. The test drives the actual formation at 3 m/s and verifies floor support along the route. This is the [Standard](campaigns/mission-events.md#scale-and-interception) class. Both roads continue visually beyond the command limits rather than ending in solid crags. This is not the support-plane rectangle or the length of the account or bundle objective.

## Marker contract

Resolve paths relative to the map and use `global_position` after instancing. Foot markers are at standing level. Layer 1 is solid and layer 2 identifies supporting surfaces for the command adapter.

| Relative path | Names |
| --- | --- |
| `Markers/Spawns/` | `Sereth`, `HouseholdGuard`, `StairGuard`, `Iren`, `VillageClerk`, `MarchMountedReserve`, `MarchStairParty` |
| `Markers/Routes/` (road and reserve) | `WestMarchEdge`, `EastMarchEdge`, `ApproachRoadWest`, `RoadBrace`, `RoadTownGate`, `RoadRecordFork`, `RoadEastReveal`, `OpenRecordApproach`, `RecordEntryBend`, `ReserveTurn`, `ReserveScreenCorner`, `CavalryWarning`, `MountedChargeStart`, `MountedRunout` |
| `Markers/Routes/` (stair, foot lane and room) | `GraveCutApproach`, `CemeteryStairFoot`, `CemeteryStairTop`, `CemeteryHold`, `GateOuterTurn`, `GateInnerTurn`, `WestLaneRoadJunction`, `WestLaneEntrance`, `LaneWestTurn`, `LaneSouthTurn`, `LaneSecurityBend`, `LaneEastTurn`, `LaneClerkTurn`, `ClerkYard`, `RecordRoomDoor`, `RecordRoomInside` |
| `Markers/Objectives/` | `WitnessAccount`, `ExposedRecords`, `AccountEntry`, `BundleSecure`, `DroppedBundleRecovery`, `EnemyRetreatExit` |
| `Markers/PhaseZones/` | `RecordRoomContest`, `BundleRetreatZone`, `CemeteryStairHold`, `OpenRoadCharge` |

Phase markers are inert footprints: their `box_size` Vector3 metadata gives full dimensions centered on the marker. Later scenarios decide contested work, tracking, or extraction. A possible command window is `Rect2(-195, -103, 390, 200)`; use closer sector views to read actual commands. With the current terrain cursor, the solid record-room roof blocks overhead picks into the interior. Stage at the marker outside the doorway; later integration can add a cutaway or objective-specific selection without changing the roof collision. The tests validate representative actor routes, collision, relative isolation and sightlines, not character AI, mounted performance, roof cutaways, or story outcomes.
