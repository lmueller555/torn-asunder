# Isolated grove and town nursery: campaign graybox

`game/battlefields/isolated_grove_nursery.tscn` is the terrain for Neris's Year Three mission [What We Planted Here](campaigns/dryads.md#1-what-we-planted-here--year-three-neris_failing_grove). It does not run the envoy encounter, summon workers, move a sled, simulate water, or declare any objective result.

For the standalone mission, run `godot game/battlefield/neris_failing_grove_playtest.tscn`. Interact with the envoy and volunteer call as Neris, then Hold a formation at the marked track screen to send back the physical forager patrol. Follow the loaded sled along the raised road and interact at the nursery. The patrol can pause loading or a nearby sled but does not deal combat damage.

Run `tests/isolated_grove_nursery_preview.tscn` with F6. **1** gives the overview, **2** a closer command sector, and **3** a hero-height loading-yard view. Figures and the loaded sled in the preview are scale references only.

```sh
godot tests/isolated_grove_nursery_preview.tscn
godot tests/isolated_grove_nursery_preview.tscn -- --hero
godot --headless --script tests/isolated_grove_nursery.gd
```

## Geography and choices

The support plane is **320 × 220 m**. Local **+X leads to the nursery**, **−Z is north**, and one unit is one meter. The loading yard, raised road, and nursery are at Y=3; the dry side track is at Y=−2.5.

- **Grove and loading yard.** The dead trunks and dry spring stand apart from the sheltered volunteer crew, envoy position, and root-ball loading pad. Defenders can reach an elevated road screen and a separate southern track lookout from the yard. The loading position and nursery receiver are separate footprints.
- **Raised road.** The **271 m** route bends above the floor of the basin. It has room for a loaded 4.8 × 7.5 m sled and clear end-stage support for the cargo footprint. Marked hold points give room to stage a screen before committing the sled.
- **Sunken threat.** A **265 m** low approach hides the foragers from the work area, winds around blind folds, passes between solid ribs, and climbs the narrow footway into the grove. Hero and formation proxies fit; the loaded sled cannot fit through either narrow section. The lookout has a line of sight to the western approach, letting a defender cover it without sending the sled downhill.
- **Nursery.** A wet-soil pad, feeder paint, and living saplings distinguish the receiving ground. The town well with its intact stone head and windlass is a physically accessible landmark outside the transplant receiver. It supplies no action or score.

The separate, unopposed **edge-to-edge reference march** runs from `WestMarchEdge` to `EastMarchEdge` via the traversable raised route. It measures **306 m / 102.2 s** with the live formation advance function at 3 m/s and normal steering at each waypoint. That is closer to the provisional 110-second map class than 90 seconds; it is not the 271 m objective route or the 320 m rectangle. Cover can hide an approach from positions that cannot see over it, but nothing here spawns a patrol or guarantees a scripted interception.

## Marker contract

Paths are relative to the map instance. Use `global_position` after instancing. Land markers sit at foot level; layer 1 is solid and layer 2 tags supporting surfaces.

| Relative path | Names |
| --- | --- |
| `Markers/Spawns/` | `Neris`, `LoadingGuard`, `TrackScreen`, `VolunteerCrew`, `RootSled`, `ForagerVanguard`, `ForagerReserve` |
| `Markers/Routes/` | `WestMarchEdge`, `EastMarchEdge`, `GroveAssembly`, `LoadingYard`, `YardExit`, `RaisedRoadWest`, `RoadScreenHold`, `RaisedRoadMiddle`, `RaisedRoadEast`, `NurseryApproach`, `TrackOverlook`, `TrackEastFold`, `TrackReedBend`, `TrackLowTurn`, `TrackPinchEast`, `TrackPinchWest`, `TrackWestMouth`, `LoadingScreenFoot`, `LoadingScreenTop`, `LoadingScreenHold` |
| `Markers/Objectives/` | `GroveEnvoy`, `VolunteerCall`, `RootBallLoad`, `TransplantBed` |
| `Markers/Landmarks/` | `ExistingWell`, `DriedSpring` |
| `Markers/PhaseZones/` | `LoadingZone`, `RaisedRoadScreen`, `TrackResponseZone`, `NurseryReceiver` |

Phase markers are inert `Marker3D` descriptors with `box_size` metadata giving full dimensions around the center. Later scenarios decide whether and when they are contested, paused or clear. A starting command bounds window is `Rect2(-151, -85, 301, 183)`; use a close tactical sector for formations and the full overview for bearings. Terrain tests use the actual command adapter and a representative oriented sled hull with axle support. They do not model worker health, loading progress, infantry pressure, or root-ball physics.
