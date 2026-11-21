# Battlefield minimap

This is an opt-in HUD widget for local battles, separate from the campaign overworld. It is north-up: battlefield +X points right, and +Z points down. It preserves the aspect of the playable field rather than stretching when the HUD changes shape. The command camera footprint is clipped at the playable boundary. Shape and color distinguish the hero, allies, a selected formation, pickups, exits, and visible enemies.

The tactical orientation, troop selection and visibility cues take inspiration from the [Kingdom Under Fire: Heroes manual, pp. 12–17](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf). This widget does not implement scouting, fog simulation, or troop ordering.

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
- Passive HUD placement does not capture mouse input. Turn on `click_to_focus` to enable the `point_requested(Vector2)` signal for clicks inside the map. The caller decides what that request does.

Headless validation: `godot --headless --script tests/battlefield_minimap.gd`.
