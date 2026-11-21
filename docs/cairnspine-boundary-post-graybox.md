# Cairnspine boundary post graybox

`game/battlefields/cairnspine_boundary_post.tscn` is a separate 300 × 190 m battlefield for Sereth's [An Audience, Not a Seizure](campaigns/undead.md#2-an-audience-not-a-seizure--year-four-sereth_pass_writ). The existing campaign catalog ID is `cairnspine_boundary_post`. This is a neutral roadside boundary post, not the Cairnspine vault road, valley assembly, or custody line. Acceptance here would admit a court claim for hearing only; it is not authority to enter the vault or use the Godbridle.

## Terrain and marker contracts

Paths below are under `Markers` and coordinates are local to the scene. The terrain has no scenario script. Markers stand in for locations, not actual actors or outcomes.

| Places | Terrain purpose |
| --- | --- |
| `Spawns/{Sereth,HouseholdPlatoon,CourtPlatoon}` | Separate west road staging. Sereth is the intended courier; neither platoon hands in the writ. |
| `Spawns/Keeper` and `Objectives/WritHandover` | Neutral shelter and separate standing position in the boundary yard. |
| `Objectives/WithdrawalRally` | Back at the west end and screened by a stone wall, not in the post's occupation area. |
| `Zones/KeeperOccupation` | Inert `Marker3D` with local `metadata/box_size` (17 × 4 × 11 m). Represents the yard where a later controller may measure hostile occupation, with warning and a chance to break it. No automatic timer or loss here. |
| `Spawns/MarchLookout` and `Routes/{TrackEmergence,HighBankScout,ScoutScreenBase}` | Actual terrain hides the trench and the low scout staging from the lookout. Climbing the bank reveals the lookout; the patrol can see travelers once they leave the trench. |
| `Spawns/MarchMountedReserve` and `Routes/{ReserveWideTurn,ReserveScreenTurn,ReserveReveal,ReserveChargeEntry}` | The reserve first sits out of sight behind a moraine. Its broad approach leads around the screen and then joins the open main road. |

The two courier approaches share only staging and the final boundary yard:

- **Road, about 262.7 m from Sereth:** west road fork → `RoadScreen` and `OpenRoadBrace` → south of the scout ramp on `ScoutRoadBypassWest/East` → `RoadEastStraight` → `LookoutBendRoad` → `PostEastTurn` → `PostRoadApproach` → handover. A visible infantry screen can draw attention and brace in the open; the reserve can also turn and run out here.
- **Foot track, about 299.2 m from Sereth:** west road fork → `WestTrackJunction` and `WestTrackTurn` → west ramp → `SheepTrackBend`, `SheepPinch` and `CoveredTrackHold` → east ramp and `EastTrackLanding` → `TrackEmergence` → `TrackWallCorner` and `PostTrackTurn` → handover. The trench is 4 m below the road, with a physical 4.8 m pinch that passes standard foot footprints but rejects the broader mounted proxy. Cover is not permanent concealment; the lookout sees the east emergence.
- Both return to the screened west rally via `RallyOpenTurn` and `RallyScreenCorner`. The covered return also uses `RallyTrackReturn`.
- A separate `ScoutRampFoot` → `ScoutRampTop` route gains 3.1 m to the scouting bank. The mounted route has about 89 m of reserve approach, then 191 m of open charge/runout to `MountedRunout`.

This is collision and visibility proof, not mounted unit behavior. The nominal mounted formation envelope (5.6 × 6 m) is sampled along the route, with turning and ground support probes. A single narrow mount may physically fit the trench; the authored restriction is for a broad mounted formation. A later adapter must issue the appropriate route or separately enforce roster restrictions. No patrol controller, horn, occupation detector, cargo or title routing is implemented.

## Scale and review

The normal edge-to-edge march uses the road and scouting-foot bypass from `WestMarchEdge` to `EastMarchEdge`. Standard movement through the command terrain adapter covers **275 m in 91.9 seconds** at 3 m/s, near the provisional **90-second** tier. This is unopposed field scale, not the distance or duration of either courier objective.

```sh
godot --headless --editor --import --quit
godot --headless --script tests/cairnspine_boundary_post.gd
godot tests/cairnspine_boundary_post_preview.tscn
```

The static review scene has **1** full overview, **2** tactical sector at the post and east emergence, **3** hero view in the foot track, and **4** hero view from the scout bank.
