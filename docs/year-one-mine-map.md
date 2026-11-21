# Year One Mine: battlefield graybox

Open `game/battlefields/year_one_mine.tscn` to edit the shared battlefield. To see the whole layout with a camera and lighting, run `tests/year_one_mine_preview.tscn` (F6 in Godot if that scene is open) or run the command from the repository root:

```sh
godot tests/year_one_mine_preview.tscn
godot --headless --script tests/year_one_mine.gd
```

The production scene adds only geometry, terrain collision (layer 1), and markers. It does not spawn actors, define objectives or their trigger volumes, attach a camera, provide navigation, or integrate with the campaign menu.

## Reading the terrain

Local **+X is east**, **−Z is north**, and one unit is one meter. The play space shares a 96 × 88 m base; ground is at Y=0, the ridge crest at Y=4. The tinted route surfaces and painted rails are non-colliding overlays.

- **Human escort.** The Godbridle starts beside the mine approach. Carry it back onto the wide exposed haul road, then through the narrower east pass. A separate north ridge position looks over the road and lets archers cover the escort without occupying the pass.
- **Orc interception.** The eastern approach forks. One party can take the low spur past the fork boulder into the pass. Another can climb the east ramp, cross the ridge, descend west, and reach the crew without committing to the pass. The ridge has two 14 m ramps with a 4 m rise, and gaps between cover blocks.
- **Druid evacuation.** Miners assemble in the yard behind the road. A timber portal leads under the spoil ridge to a second portal on the far side, then west along the screened escape trail. The 10 m tunnel has solid side walls and a 4.2 m ceiling, not a painted shortcut. Use the bottom approach to stage the withdrawal while the road is contested.

## Scene contract

Instantiate the same `PackedScene` for each campaign. Resolve these paths relative to the map instance; use a marker's `global_position` after it joins the scene tree. Markers are at walkable foot level; their local −Z gives the suggested travel or spawn facing. The names are stable hooks, not progress flags.

| Relative path prefix | Marker names |
| --- | --- |
| `Markers/Spawns/` | `HumanEscort`, `HumanInfantry`, `HumanArchers`, `OrcIntercept`, `OrcCrewParty`, `DruidGuard`, `Miners` |
| `Markers/Routes/` | `RoadWest`, `RoadJunction`, `EastPass`, `RidgeWestFoot`, `RidgeOverlook`, `RidgeEastFoot`, `OrcApproach`, `InterceptFork`, `MineYard`, `TunnelEntrance`, `TunnelMidpoint`, `TunnelExit`, `EvacuationTrail` |
| `Markers/Objectives/` | `GodbridlePickup`, `GodbridleExit`, `MinerAssembly`, `MinerEvacuation` |

For the next playable pass, connect scenario state to these markers, bake and test navigation on ramps and under the tunnel roof, and tune formation width and patrol/escort spacing in play. The graybox tests sample individual capsule clearance, not formation behavior or full battle balance.
