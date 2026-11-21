# Red Basin well road: campaign-scale graybox

`game/battlefields/red_basin_well_road.tscn` is the terrain for [The Second Bucket](campaigns/orcs.md#2-the-second-bucket--year-three-orc_well_road), Raska's Year Three convoy. It is geometry only: no playable escort, riders, boarding, hidden timer, fake charge, or campaign progression.

Run `tests/red_basin_well_road_preview.tscn` with F6. Keys **1**, **2**, and **3** switch among basin overview, command sector, and hero-height inspection from the archer shoulder. Figures and cart boxes show scale only.

```sh
godot tests/red_basin_well_road_preview.tscn
godot tests/red_basin_well_road_preview.tscn -- --hero
godot --headless --script tests/red_basin_well_road.gd
```

## The route choice

The basin support plane is **340 × 240 m**, one unit per meter, **+X east to the exit**, **−Z north**. The salt deck stands at Y=0, the dry wash floor at Y=−4, and the archer shoulder at Y=3.5.

- **Well yards.** The higher cart stages beside the upper well. The lower cart starts separately beside a physical storehouse and a boarding apron for the waiting households. The lower storehouse interaction and cart boarding points are distinct. A western entry grade connects the two levels, so either cart can choose either route.
- **Salt road.** The shorter road is a straight, exposed 20 m strip. A mounted reserve begins behind north-bank cover, turns around the screen, becomes visible at the warning point, and reaches a straight charge segment. Infantry have room to brace in the open, but a cart offers an unobstructed target.
- **Dry wash.** The longer winding route runs below the salt deck and breaks sightlines at multiple crags. It has one east exit ramp, 10 m wide between solid shoulders, before both routes meet at the high-bank rally and use the same marked Basin exit. The elevated archer stand sees the ramp and road; it does not give uninterrupted sight through the wash.

| Start and finish | Salt | Wash |
| --- | ---: | ---: |
| Upper cart, from its well to Basin exit | 302 m | 424 m |
| Lower cart, via boarding to Basin exit | 350 m | 378 m |

## Scene contract

Resolve each path below relative to the scene instance, and read `global_position` after adding it to the tree. Land markers sit at foot level. Layer 1 is solid; layer 2 tags the supporting surfaces for the command terrain adapter.

| Relative path | Names and role |
| --- | --- |
| `Markers/Spawns/` | `RaskaHero`, `BraceInfantry`, `BasinArchers`, `UpperWellCart`, `LowerWellCart`, `LowerHouseholds`, `MountedReserve`, `RivalLevy` |
| `Markers/Routes/` (well and salt) | `UpperWellHead`, `UpperWellStaging`, `LowerWellHead`, `LowerWellStaging`, `WestApproachFork`, `SaltRoadWest`, `SaltChargeGate`, `SaltRoadEast`, `HighBankRally` |
| `Markers/Routes/` (wash and shoulder) | `WashEntryTurn`, `WashWestBend`, `WashReedBend`, `WashBlindBend`, `WashLongBend`, `WashEastBend`, `WashRampTurn`, `WashRampFoot`, `WashRampTop`, `ArcherShoulderStart`, `ArcherShoulder` |
| `Markers/Routes/` (riders) | `MountedReserveTurn`, `MountedScreenCorner`, `MountedWarning`, `MountedChargeStart`, `MountedRunout` |
| `Markers/Objectives/` | `LowerStorehouse`, `LowerBoarding`, `BasinExit` |
| `Markers/PhaseZones/` | `LowerBoardingArea`, `SaltChargeLane`, `WashRampChoke`, `BasinExitZone` |

Phase zones are inert `Marker3D` descriptors with `box_size` Vector3 metadata (full extents about the marker). They don't trigger anything. For integration, evaluate `Rect2(-154, -98, 316, 199)` and issue staged waypoints around the wash bends. The terrain test exercises both cart/route combinations with a 2.6 × 4.6 m oriented box plus axle supports, eight hero/formation routes, sightlines and depth. It does not model suspension, mounted movement, simultaneous convoy capacity, battle pressure, or mission balance.
