# Battlefield minimap

This is an opt-in HUD widget for local battles, separate from the campaign overworld. It is north-up: battlefield +X points right, and +Z points down. It preserves the aspect of the playable field rather than stretching when the HUD changes shape. The command camera footprint is clipped at the playable boundary. Shape and color distinguish the hero, allies, a selected formation, pickups, exits, and visible enemies.

The tactical orientation, troop selection and visibility cues take inspiration from the [Kingdom Under Fire: Heroes manual, pp. 12–17](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf). The widget does not simulate scouting or fog, and it emits location requests rather than deciding how to issue or validate an order.

## Mara's campaign mine

The campaign-size escort uses a lower-right minimap that stays passive in hero view. The pickup changes to the east exit once Mara has the Godbridle; holding L2 shows the active command camera's footprint. When interception is reported, the warning marks the pass, not the Orc's position. The Orc only appears as a live contact when Mara or a living allied formation is within 48 m with an unobstructed view. The contact disappears when sight is lost or the Orc is defeated. The small mine prototype is unchanged.

Hold **L2 / Shift** to make the minimap interactive. Left-click a map point to inspect that tactical sector. Right-click walkable ground to issue a Move to the selected platoon. Clicking the map margin or a solid obstacle never issues a world order through the HUD. The minimap stays passive in hero view. Mara’s live minimap remains mouse-only. Controller cursor input is available in the separate development preview below; the live HUD does not queue waypoints.

## Controller cursor development preview

Run `godot game/battlefield/controller_minimap_playtest.tscn` after importing. In tactical or ally-follow view, press **D-pad Up / N** to enlarge the minimap and start a Move draft for the selected platoon. Use the left stick, D-pad, or keyboard arrows to aim. **R1 / G** appends the highlighted point and keeps the map open; it works on the tactical cursor too, and both views use the same eight-point pending route for the selected platoon. **Cross / Enter** replaces the route with one Move. **Circle / Esc** closes the map and discards only the unsent point. Accepted waypoints keep running and clear in order on arrival; Hold clears the route. Entering direct hero action cancels the unfinished draft, and a stick held through close must return to neutral before it can move the hero. This uses the existing debug field and minimap, with no change to Mara’s mouse bindings.

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
