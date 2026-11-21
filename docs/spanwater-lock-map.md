# Spanwater Lock: shared Year Four battlefield graybox

[Orcs](campaigns/orcs.md), [Dryads](campaigns/dryads.md), and [Elves](campaigns/elves.md) all use `res://game/battlefields/spanwater_lock.tscn`. Open that scene to edit the geometry. F6 on `tests/spanwater_lock_preview.tscn` opens a lit overview without starting the campaign.

```sh
godot tests/spanwater_lock_preview.tscn
godot --headless --script tests/spanwater_lock.gd
```

## Reading the terrain

Coordinates are local meters, **+X east/downstream**, **−Z north**. The old Basin riverbed is at Y=0 and the high banks are at Y=3. Tinted channels and route strips are non-colliding guides. This isn't a playable mission and does not simulate, render, or move water.

- **Orc route.** Follow the raised service causeway from upstream, across the feeder inlet bridge and onto the exposed lock apron. The narrower lock stair offers infantry cover; it uses smooth ramp collision beneath its marked treads. The blue spillway spans the old Basin riverbed. Its wheel is north of the river; the rust-colored sea gate is physically closed across a different branch to the south. The low crossing spans the dry riverbed east of the main lock. The raised route to the high exit doesn't depend on that shortcut.
- **Dryad route.** Follow the green feeder's north bank from the inlet debris rack to the downstream gauge. Both stations are reached from the same raised maintenance path without touching the wheel, low crossing, or landing.
- **Elven route.** The near and far households start on the south bank. A screened approach leads to a low timber landing, with a ramp and visible stair treads. The launches have a separate route through the old riverbed with an upstream hold, outflow hold, shared berth, and downstream exit.

## Scene contract

Resolve paths below relative to the map instance, and read `global_position` after adding it to the scene tree. Foot markers are at standing height (origin at feet); boat markers suggest waterline positions, not actor spawns on a walkable floor. Terrain collision is on layer 1.

| Relative path prefix | Marker names |
| --- | --- |
| `Markers/Spawns/` | `OrcVanguard`, `OrcSupport`, `MarchDefenders`, `DryadCrew`, `DryadGuard`, `ElfMarines`, `HouseholdsNear`, `HouseholdsFar` |
| `Markers/Routes/` | `UpstreamApproach`, `ServiceCauseway`, `LockApron`, `LockStairFoot`, `LockStairTop`, `HighBank`, `LowCrossingNorth`, `LowCrossing`, `LowCrossingSouth`, `FeederPathWest`, `FeederPathEast`, `LandingApproach`, `LandingFoot` |
| `Markers/Objectives/` | `SpillwayWheel`, `SeaGate` (landmark only), `HighBankExit`, `FeederInletRack`, `TownGauge`, `LowLanding` |
| `Markers/BoatRoute/` | `UpstreamHold`, `OutflowHold`, `BoatBerth`, `BoatExit` |
| `Markers/PhaseZones/` | `LowCrossingClosure`, `LandingClosure` |

Phase markers have a `box_size` Vector3 metadata field in meters (full extents, centered on the marker). They are not colliders or triggers and have no effect by themselves. A future scenario may use them to close the low crossing to land traffic and halt boarding while leaving launches already away free to depart. All other marker names are placement hooks only. Campaign logic, objective interactions, unloading/boarding, hydrology, navigation, and final art are future work. The current test checks individual foot clearance and boat sightlines, not formation or launch handling.
