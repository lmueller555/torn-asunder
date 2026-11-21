# Battlefield minimap

This is an opt-in HUD widget for local battles, separate from the campaign overworld. It is north-up: battlefield +X points right, and +Z points down. It preserves the aspect of the playable field rather than stretching when the HUD changes shape. The command camera footprint is clipped at the playable boundary. Shape and color distinguish the hero, allies, a selected formation, pickups, exits, and visible enemies.

The tactical orientation, troop selection and visibility cues take inspiration from the [Kingdom Under Fire: Heroes manual, pp. 12–17](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf). The widget does not simulate scouting or fog, and it emits location requests rather than deciding how to issue or validate an order.

## Mara's campaign mine

The campaign-size escort uses a lower-right minimap that stays passive in hero view. The pickup changes to the east exit once Mara has the Godbridle; holding L2 shows the active command camera's footprint. When interception is reported, the warning marks the pass, not the Orc's position. The Orc only appears as a live contact when Mara or a living allied formation is within 48 m with an unobstructed view. The contact disappears when sight is lost or the Orc is defeated. The small mine prototype is unchanged.

Hold **L2 / Shift** to make the minimap interactive. Left-click a map point to inspect that tactical sector. Right-click walkable ground to issue a Move to the selected platoon. Clicking the map margin or a solid obstacle never issues a world order through the HUD. The minimap stays passive in hero view. On a controller, keep **L2** held and press **D-pad Up** to aim a separate map cursor. Use the left stick or D-pad; **Cross** sends a single Move to the selected platoon and recenters the tactical sector, while **Circle** or releasing L2 closes without a new order. Hold the stick through closing and it stays inactive until you return it to neutral. Nothing opens in hero view. In the campaign Mine, **R1 / G** appends a waypoint from either the tactical cursor or the focused map, up to eight pending for the selected platoon. Circle discards only the unsent point; accepted legs keep marching. A direct Move replaces them, and Hold or an accepted Attack clears them. In command view, both the regular minimap and the focused cursor show the selected platoon’s numbered pending points. The highlighted leg joins that platoon’s current position to the first point only while marching toward it. The route is hidden in hero view without stopping the platoon, and never includes enemy orders.

## Sereth’s Cut

Hold **L2 / Shift** for the command minimap. **Left-click** inspects a sector and **right-click** sends a single Move. With L2 held, **D-pad Up** opens a separate map aim. Use the left stick or D-pad, then **R1 / G** to append without closing the draft, or **Cross** to replace the route with a single Move. Without a draft, **R1 / G** appends the tactical cursor. The selected guard’s eight-point limit counts its current leg. Appends need both a walkable overhead hit (not the Record Room roof) and room for the formation. Each leg is a straight Move; a valid endpoint does not promise a clear path. If a guard hits a barrier, the route pauses without skipping that point. Send an ordinary Move to safe ground to replace it, or Hold to clear it. **Circle**, releasing L2, and focus loss cancel the unsent point, not accepted movement. That movement continues when the map hides. Routes reset with the mission and never reveal raiders.

## Ilyra’s Two Shorelines

Hold **L2 / Shift** to see a passive, north-up survey map alongside the tactical view. It shows Ilyra, the Shore Detachment, and the command camera’s current ground footprint. A reading becomes a diamond only after Ilyra records it; both relay sites appear as gates when both readings are ready. Gates mark choices, not an open signal window. The map shows no cutter, crews, or routes and never takes mouse or controller input. The world guides, signal readout, Move and Hold still work as before. Releasing command hides the map.

## Controller cursor development preview

Run `godot game/battlefield/controller_minimap_playtest.tscn` after importing. In tactical or ally-follow view, press **D-pad Up / N** to enlarge the minimap and start a Move draft for the selected platoon. Use the left stick, D-pad, or keyboard arrows to aim. **R1 / G** appends the highlighted point and keeps the map open; it works on the tactical cursor too, and both views use the same eight-point pending route for the selected platoon. **Cross / Enter** replaces the route with one Move. **Circle / Esc** closes the map and discards only the unsent point. Numbered points are the selected platoon’s accepted pending route. The gold line runs from its current position to its active destination and advances when the platoon reaches the next point. It disappears when the platoon is not moving. Hold clears the route. Entering direct hero action cancels the unfinished draft, and a stick held through close must return to neutral before it can move the hero. This uses the existing debug field and minimap without affecting campaign controls outside Mara’s Mine.

### Try the existing Mine terrain

Run `godot game/battlefield/controller_mine_route_playtest.tscn` for the same controls on the existing large Year One Mine, without the practice opponents. Select **Scouts**, then use **D-pad Up / N** and **R1 / G** to plot the broad west ramp: approach northwest of the scouts, reach the foot, then head east along the center to the crest (editor markers: `RidgeWestApproach` → `RidgeWestFoot` → `RidgeWestCrest`). The minimap rejects the top of the tunnel roof, solid cover, and points where a formation cannot fit. Each accepted leg is a straight Move: an allowed destination does not guarantee a clear path through a cliff or wall. Mara’s Mine uses the same footprint validation for waypoint appends; a direct Move keeps the existing map-pick rule.

## Preview

```sh
godot --headless --editor --import --quit
godot tests/battlefield_minimap_preview.tscn
```

Click the map to move the sample command footprint, cycle the selected formation, or toggle enemy visibility to see the enemy disappear. The fixture animates independently of a mission.

## Integration contract

- Instantiate `game/battlefield/battlefield_minimap.gd` as a `Control`. Call `set_field_bounds(Rect2)` with the playable X/Z rectangle and optionally supply a north-up `terrain_texture` covering that exact rectangle.
- Call `show_frame(Minimap.Frame)` with stable, unique marker IDs and current X/Z coordinates. Supply an optional hero heading, current allies and selected ally ID, pickup/exit objectives, and the ground points from the active command camera's corners in perimeter order. An empty footprint hides the sector.
- Pass **only currently visible enemies** in `visible_enemies`. The widget does not retain former contact positions and has no knowledge of any enemies outside that list.
- Passive HUD placement does not capture mouse input. Turn on `click_to_focus` to enable the `point_requested(Vector2)` signal for clicks inside the map. If it also opts in to `right_click_to_move`, right-click emits a `move_requested(Vector2)` signal. The caller decides whether the requests are valid and how to act on them.

Headless validation: `godot --headless --script tests/battlefield_minimap.gd`.
