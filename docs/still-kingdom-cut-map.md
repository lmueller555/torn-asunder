# Still Kingdom cut and village: campaign graybox

The [approved V7 S3TC cemetery stair kit](audits/cut-cemetery-stair-v7.json) replaces the old stair visuals, retaining sides, and footing in this placement. The original smooth traversal collision, cover and objective markers remain. The rest of the map has not passed its visual audit.

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

The separate **normal edge march** is **386 m / 128.7 s** through the traversable road markers, measured by driving the current formation model at 3 m/s through the actual terrain adapter. It is near the provisional 130-second class. This benchmark is not the support-plane rectangle or the length of an account/bundle objective path.

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
