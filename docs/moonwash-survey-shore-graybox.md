# Moonwash Survey Shore: campaign terrain graybox

`game/battlefields/moonwash_survey_shore.tscn` is new terrain for Ilyra's [Two Shorelines](campaigns/elves.md#2-two-shorelines), not the post-rise harbor from Hulls on Stone. It is a static 360 × 244 m envelope with two elevations (+1.2 m coast and +7.2 m apron, relative to water). The map is static; the standalone Two Shorelines prototype below supplies the moving cutter, shore crews and signal play. The [pure objective controller](../game/battlefield/ilyra_coast_survey.gd) stays the authority for read/secure/LOS/hold/complete outcomes.

## Land contracts

All coordinates below are local to the battlefield. All spawns, visits and turns are `Marker3D` nodes, not scripted cutovers.

| Path under `Markers` | Use |
| --- | --- |
| `Spawns/Ilyra`, `Spawns/ShoreDetachment` | Separate west-coast hero and formation staging |
| `Objectives/AncestralStone` | Standing approach to the ancestral slab, behind the western shoulder |
| `Objectives/FishingInlet` | Living fishing cove, working jetty and skiff, separate from the ancestral memorial |
| `Objectives/BeachSignal` | Early exposed relay. About 20 m from the inlet via `InletBeachTurn`. |
| `Objectives/HeadlandSignal` | Elevated relay. About 241 m from the inlet via `InletBacktrack`, `HeadlandInlandCut`, `HeadlandLandwardTurn`, `HeadlandRampFoot`, `HeadlandRampTop`, `HeadlandApron` and `HighGuard`. |
| `Spawns/LandingCrew` → `Routes/LandingLine` → `Routes/LandingWarning` → `Objectives/BeachSignal` | Exposed beach pressure; a direct contest lane |
| `Spawns/HeadlandPressure` → `Routes/HeadlandReserveTurn` → `Routes/HeadlandGuard` → `Routes/HeadlandRampFoot` → `Routes/HeadlandRampTop` | Independent landward pressure lane. The ramp can be held; the high apron isn't immune. |

The landward slope is ~6 m in 35 m, with 10 m of physical width. Beach approach cannot climb the apron from the side. Solid headland rocks and apron screens shield the high guard from the beach landing lane; formations can still defend either site. Terrain tests check collision and sightlines, not pressure timing or autonomous pathfinding.

## Cutter route and sightlines

Read the ordered children of `Markers/BoatRoute` or use their names below. All markers are the waterline (Y=0); the prototype uses a 2.5 m receiver and a graybox hull. The loop is about **661 m**, measured segment-by-segment including the return to the first point.

```text
WestBlindPass → WestRound → BeachApproach → BeachHold
→ EastBlindPass → ShoalReturnBend → HeadlandApproach → HeadlandHold
→ EastOuterTurn → OuterEast → OuterWest → WestBlindPass …
```

- `BeachApproach` and `HeadlandApproach` are visible advance-warning points from their matching signal sites, **not stops**. `BeachHold` and `HeadlandHold` expose each corresponding acknowledgment opportunity. The cutter holds for 12 seconds at each stop and returns after a miss. This does not imply that the cutter should cruise at infantry speed or that these are the only points visible.
- From the beach, `WestHeadland` hides the cutter at `WestBlindPass`. From the high site, a different landmass, `EastHeadland`, hides it at `EastBlindPass`. Tests check the first actual solid collider, not a nominal phase flag. Tested at a 2.6 m land signal origin and 2.5 m receiver above water.
- The pale shoal has colliding submerged bars, not just painted shallows. A 5 × 12 m nominal hull with 1.25 m draft clears the marked polyline and rotating corners; the straight cut hits the bars. This is sampled static clearance, not a sailing model, and should be repeated if the cutter footprint or draft changes.
- Solid geometry uses collision layer 1. Only dry ground, the jetty and the ramp/apron are also tagged walkable (layer 2). The visual water has no collision or buoyancy. The prototype keeps land movement and the cutter route in their own domains. The dry-ground probe assumes valid land spawns.

## Scale and inspection

Representative unopposed edge route: `WestMarchEdge → WestCoastLane → InlandJunction → MidCoastLane → HeadlandRoadFork → WestRampBypass → EastRampBypass → FarCoastLane → EastMarchEdge`. A real formation using the standard terrain adapter finishes the **356 m** route in **118.7 seconds at 3 m/s**, provisionally the 110-second class. This is dry-lane scale, not a mission timer or the boat/hero objective distance.

```sh
godot --headless --editor --import --quit
godot --headless --script tests/moonwash_survey_shore.gd
godot tests/moonwash_survey_shore_preview.tscn
```

Preview keys: **1** overall coast, **2** local command view, **3** beach hero view, **4** headland hero view. The dotted line, hold rings, figures and docked cutter proxies are static inspection aids, not mission actors or UI. Ocean and formations are graybox shapes, not final art.

## Standalone Two Shorelines prototype

```sh
godot game/battlefield/ilyra_coast_survey_campaign.tscn
godot --headless --script tests/ilyra_coast_survey_campaign.gd
```

Follow the amber trails to the stone and working inlet and use **Cross / Space** to record each reading. The first reading gets the survey cutter under way on its full shoal-safe loop; the second draws the two port crews toward their respective relays. Their routes continue while you command. The cutter’s labeled cyan route and both marked holds appear in command view (**L2 / Shift**). The HUD distinguishes an obstructed signal, a visible approach, and a cutter actually stopped at the matching relay.

Send the Shore Detachment along the inland lane to the blue guard ring at either relay. **Square / right-click** issues Move; **Cross / H** holds in command view. Ilyra can request transmission only in hero view at the selected relay; a clear terrain ray, physical cutter stop, and three uninterrupted seconds at a staffed and uncontested relay are required. If interrupted, only the signal resets. Use **Options / Backspace** or the HUD button to retry. Either relay acknowledges the same complete chart, and neither requires defeating a crew.

This prototype covers route choice and local pressure, not hero injuries, cutter combat, tides, port fleet support, or campaign routing. Its completion signal emits `chart_circulated` once after the cutter acknowledges both readings.
