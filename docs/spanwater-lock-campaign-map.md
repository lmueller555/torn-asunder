# Spanwater Lock: campaign-scale battlefield graybox

`game/battlefields/spanwater_lock_campaign.tscn` is the large, shared version of the Year Four site from the [Orc](campaigns/orcs.md), [Dryad](campaigns/dryads.md) and [Elven](campaigns/elves.md) campaigns. The smaller [Spanwater pocket](spanwater-lock-map.md) is unchanged. Neither water nor mission state is simulated by this scene.

Open `tests/spanwater_lock_campaign_preview.tscn` and press F6. Press **1** for the basin, **2** for a closer lock command sector, or **3** for hero-height inspection from the spillway approach. The figures are 1.8 m scale references only.

```sh
godot tests/spanwater_lock_campaign_preview.tscn
godot tests/spanwater_lock_campaign_preview.tscn -- --hero
godot --headless --script tests/spanwater_lock_campaign.gd
```

## Scale and decisions

The terrain support plane measures **360 × 240 m**. Coordinates are local meters; **+X east/downstream**, **−Z north**. Working bank surfaces are at Y=5 and the channel bed is at Y=0. The colored surfaces are navigation guides, not animated water.

- **Orcs.** Advance on the raised service causeway, over the still-open feeder inlet, then across the exposed apron or up a covered infantry stair. The wheel sits on the main channel; the physically closed sea gate is on its own branch south of the river and not a player objective. Return upstream along the raised road for lower-company withdrawal, or east across the high bank for the **191 m** extraction route. A separate reserve begins out of sight of the wheel and can round the apron wall.
- **Dryads.** A separate northern maintenance route links the inlet rack, a mid-path staging bend, and the downstream gauge. From the crew spawn the marked path is **287 m**. Its deck can serve both stations without crossing the apron, low ford, or landing.
- **Elves.** Near and far household groups have distinct arrival paths, converging above the low timber landing. The far approach turns behind a screen before reaching the bank ramp. A different water corridor passes the hold points and berth, then returns east through the boat exit. Raised stairs beside the ramp make the lower landing's elevation legible.
- **Phase geometry.** The north and south ramps meet at an exposed dry crossing before release. Future flood/boarding code can use two independent authored volumes; closing the ford must not close the raised way out or the landing automatically. This scene does not activate either.

## Measured dry perimeter march

A standard infantry formation takes **157.17 seconds** to march **471.28 m** at 3 m/s in either direction between the north town-bank crags and the south rim. A direct crossing and the straight shortcuts between the measured bends are blocked. The route passes over the western service bridge, then heads east on the upper bank to cross the dry ford. This qualifies as **Large** without a detour for combat or a mission objective.

The route is available in Raska’s live mission while the spillway stays closed. Neris’s and Ilyra’s timed releases can close the ford before a normal march reaches it, so their measurements describe the initial dry terrain, not a route guaranteed during their missions. Run `godot --headless --script tests/spanwater_perimeter_march.gd` after importing to verify legal command points, rim collisions, the blocked shortcuts, and both directions in the three registered layouts.

## Marker and camera handoff

All [pocket marker paths](spanwater-lock-map.md#scene-contract) are preserved with the same meaning at newly authored positions, including the two inert phase boxes. Added paths under `Markers/Routes/`:

| Marker | Location and role |
| --- | --- |
| `OrcWithdrawalExit` | Upstream end of the causeway; route back via `LockApron`, `ServiceCauseway` and `UpstreamApproach`. |
| `MarchReserveAssembly`, `MarchScreenTurn`, `MarchCounterattackApproach` | Screened start, corner, and clear apron lead-in; keep the approach on the upper deck. |
| `HighBankStaging` | Intermediate high-bank point between the wheel and east exit; doesn't use the ford. |
| `ReleaseSweepStart`, `ReleaseSweepEnd` | Y=0 inlet/outlet of an 87 m straight +X sweep toward the ford at Z=0; 12 m of unobstructed stream width around the center. |
| `FeederMaintenanceBend`, `HouseholdScreenTurn` | Additional on-foot bends for the independent raised Dryad and Elven approaches. |

Land markers sit at foot level. Boat marks are authored waterline positions, Y=0.4. `PhaseZones/LowCrossingClosure` and `PhaseZones/LandingClosure` stay inert `Marker3D` nodes with a positive Vector3 `box_size` (full dimensions centered on the marker). Use scene-relative paths and resolve global positions after instancing. Solid collisions are on layer 1; walkable supports are also on layer 2.

For later playable integration, evaluate a local bounds window around `Rect2(-166, -105, 336, 206)` and start the tactical camera near the active sector; use overview for orientation, not formation detail. All authored land routes fit within the existing terrain adapter’s floor probes. The test checks individual hero and nominal formation movement, low-level boat clearance, and open or screened rays. It does not implement water, navigation, embarkation, runtime counterattacks, or balance.
