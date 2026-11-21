# Cairnspine assembly and vault road: shared campaign graybox

The fixed terrain in `game/battlefields/cairnspine_vault_road.tscn` belongs to the Year Five [Druid vault return](campaigns/druids.md#3-no-new-command), [Dryad passage](campaigns/dryads.md#3-a-road-we-can-share--year-five-neris_cairnspine_passage), and [Undead court stand](campaigns/undead.md#3-the-lamp-in-the-window--year-five-sereth_no_proxy). The valley's assembly area also provides the separate Year Three [public hearing](campaigns/druids.md#2-let-them-walk-out) venue. There are no live campaign controllers, inhabitants, objectives, or hearing scripts in this scene.

Run `tests/cairnspine_vault_road_preview.tscn` with F6. **1** gives the whole pass, **2** the local tactical sector around the forecourt, and **3** a hero-height view along the narrow shelf. Capsule figures are 1.8 m scale references, not actual units.

```sh
godot tests/cairnspine_vault_road_preview.tscn
godot tests/cairnspine_vault_road_preview.tscn -- --hero
godot --headless --script tests/cairnspine_vault_road.gd
```

## Terrain choices

The support plane is **340 × 250 m**, with one unit per meter, **+X toward the vault** and **−Z north**. Walkable heights run from the valley at Y=0, through the side-path bench at Y=8, to the forecourt and terrace at Y=12. Crags break lines of sight; paved markings don't change movement.

- **Valley assembly.** The wide foot of the pass holds separate assembly, refugee, and witness staging points. The short-shelf and long-side decision markers branch from the same safe staging ground. Neither path is gated.
- **Shelf or flank.** The shelf is **218 m** from safe staging to the forecourt, with a 9 m crest, a solid inner screen, and a genuine open drop on the outer edge. The flank is **287 m** between the same endpoints: a wider bench with two slopes and a blind bend, then a dogleg to the rejoin. The different heights, cover and paths affect orders; one isn't a uniformly scaled copy of the other.
- **Forecourt, terrace and vault.** A screened north reserve can reach the forecourt after rounding its cover. The route to the witness terrace branches before the custody line. Witnesses can see the vault entrance from their own terrace, without walking through custody or closure. The forecourt, custody line, bridle return, and terrace are separate hooks for Sereth, Sova and Neris.
- **Public hearing.** The valley contains two different Year Three lectern placements. The open dais can be approached from the north or west; the recessed dais has solid rear/side cover and a narrower public approach. Each has an independent ring footprint, scribe placement and clear public exit. None of the Year Five objectives is used to run the hearing.

## Measured perimeter march

In each registered Year Five deployment, a standard unopposed infantry formation marches **522.48 m in 174.20 seconds** at 3 m/s in either direction. The north and south endpoints are within about 2 m of solid perimeter crags, not the command boundary. The forecourt foundations block the direct crossing, so the measured route follows the valley floor around the west foot of the raised pass. This is an **Expansive** terrain benchmark, not the time to reach or complete a mission objective.

The six command-selectable points (X/Z in meters, north to south) are `(124, -79) → (-75.5, -47.5) → (-90.5, -35.5) → (-51.5, 74) → (21, 83) → (133, 83)`. Run `godot --headless --script tests/cairnspine_perimeter_march.gd` after importing to reproduce the march through each deployment's movement adapter at 60 Hz. The test also checks the crags and verifies that straight shortcuts between nonadjacent route points are blocked. It does not add terrain, objective markers, or pathfinding.

## Marker contract

Paths are relative to the map instance. Use `global_position` after instancing. Land markers sit at foot level. Layer 1 is solid and layer 2 tags only walkable supporting surfaces.

| Relative path | Role and key names |
| --- | --- |
| `Markers/Spawns/` | `SovaCarrier`, `KeeperShelfGuard`, `KeeperSideGuard`, `NerisGuide`, `DryadScreen`, `SerethHousehold`, `CourtEscort`, `RivalReserve`, `SidePressure`, `SovaHearing` |
| `Markers/Routes/` | `ValleyAssembly`, `SafeStaging`, `RefugeeStaging`, `WitnessStaging`, `ShelfDecision`, `ShelfFoot`, `ShelfClimb`, `ShelfHold`, `ShelfRejoin`, `SideDecision`, `SideApproach`, `SideTurn`, `SideRampFoot`, `SideBlindBend`, `SideRampTurn`, `SideNorthToe`, `SideHighBend`, `SideRejoin`, `Forecourt`, `TerraceApproach`, `TerraceEntry`, `RivalReserveCorner`, `RivalReserveReveal` |
| `Markers/Objectives/` | `VaultEntrance`, `BridleReturn`, `CustodyLine`, `WitnessTerrace`, `RefugeeSafety`, `AttestingWitnesses` |
| `Markers/Hearing/` | `OpenLectern`, `OpenRingCenter`, `OpenNorthApproach`, `OpenWestApproach`, `OpenPublicExit`, `OpenScribe`, `RecessedLectern`, `RecessedRingCenter`, `RecessedApproach`, `RecessedPublicExit`, `RecessedScribe` |
| `Markers/PhaseZones/` | `VaultClosure`, `TerraceSafeZone`, `CustodyLineZone`, `OpenHearingRing`, `RecessedHearingRing` |

Phase zones are inert descriptors, each with a `box_size` Vector3 for full dimensions centered on its marker. A later scenario decides when to use a footprint and what crossing it means. For eventual command integration, evaluate `Rect2(-154, -105, 299, 212)` as a battlefield window; use the overview for orientation and the near sector to read platoon-scale actions. The actual terrain adapter tests 17 hero and nominal formation routes, relative widths, blind and clear sightlines, and marker separation. It does not implement AI routing, fall behavior, hearing pressures or victory conditions.
