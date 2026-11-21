# Year One Mine: campaign-scale battlefield graybox

`game/battlefields/year_one_mine_campaign.tscn` is a separate, large 3D layout for the [shared Year One encounter](combat.md#year-one-battle-at-the-mine). The [96 × 88 m mine pocket](year-one-mine-map.md) remains the existing playable prototype and is unchanged. The campaign scene is not yet wired to missions or the command runtime.

Open `tests/year_one_mine_campaign_preview.tscn` and press F6. Press **1** for the full valley, **2** for the local command sector, or **3** for the road at hero height. The 1.8 m capsules give scale, not combat or formations. The command view frames a 116 m vertical span around the pass so troop-scale detail isn't lost in the valley-wide view. The hero view uses a 65° lens and a follow-distance proxy of about 6 m.

```sh
godot tests/year_one_mine_campaign_preview.tscn
godot tests/year_one_mine_campaign_preview.tscn -- --hero
godot --headless --script tests/year_one_mine_campaign.gd
```

## Distances and tactical choices

The support plane is **360 × 260 m** (convention: +X east, −Z north, one unit per meter). Crags frame the valley and break sightlines between the approaches. The tallest terrain is scenery; routed floors range from Y=0 to Y=10. The painted shoulders and track beds are visual guides, not movement modifiers.

- **West assembly and quarry turn.** A screened yard gives the infantry room to form up before the road bends around the quarry. The approaches split here: archers go north and climb the gentler ramp; the hero and escort continue south to the works.
- **Works and miner escape.** The mining yard near the spring leads to a timber portal and a 38 m enclosed tunnel with a separate evacuation turn behind the ridge. The **118 m** marked route carries miners from assembly through the tunnel and across a screened hollow. The spoil ridge interrupts the direct yard-to-hollow sightline.
- **Haul road and interception.** The marked delivery is about **260 m** from pickup via the quarry junction, road cut, and pass to the boundary. These sections expose different decisions: protect the pickup at the yard, move archers onto the 10 m ridge, choose whether to hold the choke or guide the escort through it. The Orc rear approach forks into a ridge route to the crew and a screened spur to intercept the road.
- **Pass reserves.** The Orc east reserve sits off the main road with a second approach into the interception mouth. South of the road, a longer traverse connects a reserve pocket, a screened flank cut and the pass fallback without crossing the narrowest part of the throat. It changes where a formation can enter the fight; it isn't a duplicate straight road.

At the current prototype's **5.5 m/s hero** and **3 m/s formation** speeds, 260 m is about **47 s / 87 s of uninterrupted travel**. These are pacing estimates, not win targets. Later mission passes should test whether movement and competing orders fill those windows, and shorten or move a decision point if its approach feels idle.

## Integration contract

All [mine pocket marker paths](year-one-mine-map.md#scene-contract) exist here with the same names and roles, at newly authored positions. Extra routes are under `Markers/Routes/`: `WestAssembly`, `QuarryTurn`, `RoadCut`, `PassRelease`, `RidgeWestApproach`, `RidgeWestCrest`, `RidgeEastCrest`, `InterceptMouth`, `InterceptRoadMerge`, `EastReserve`, `SouthReserve`, `SouthTraverse`, `SouthFlankCut`, `PassFallback`, and `EvacuationTurn`. Position markers are at foot level; read their `global_position` after instantiation.

- For command integration, start by evaluating **`Rect2(-160, -108, 320, 224)`** as the local playable window, then tune it with the camera and mission. The wide view is for orientation; near-sector framing, a pan target, and formation/waypoint overlays should do the actual command work.
- Solid geometry is on physics layer 1; only genuinely walkable support surfaces are also on layer 2. Existing ground probes from local Y=20 to −8 can sample every route without hitting hilltops or the tunnel roof. The existing 1.7 m formation radius is a proxy, not a full real formation.
- Follow the staged waypoints rather than issuing a single straight move between distant objectives. The route test checks 11 sampled paths with the current terrain adapter, both hero and formation probes, cross-route clearance at six decision sites, and cover/line of sight. It does not test AI pathfinding, regrouping, camera controls, objective timing, or battle balance.

The reference is the original [*Kingdom Under Fire: Heroes* Xbox manual, pp. 12–21](https://www.gamesdatabase.org/Media/SYSTEM/Microsoft_Xbox/Manual/formated/Kingdom_Under_Fire-_Heroes_-_Microsoft_Game_Studios.pdf), especially waypoint movement, tactical-map awareness, formation choice and immediate hero control at contact. [Blueside's game page](https://www.blueside.co.kr/ENG/games/kufheroes.asp) likewise describes the Action RTS pairing of personal combat and leading an army. Those mechanics inform the spacing between sectors and the two viewing distances. This map, its terrain and its dimensions are original prototype choices, not measurements or a recreation of an Xbox map.
