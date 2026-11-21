# Vareth overworld development playtest

This is a scoped opt-in Godot playtest, not a replacement for normal campaign startup. From the repository root:

```sh
godot --headless --editor --import
godot --path . --script res://game/overworld/marches_overworld_playtest.gd
```

Choose New Game and Mara. Arrow keys, D-pad, or mouse select visible sites. Enter, controller A, or the contextual button confirms the selection. Escape or B cancels travel (returning to the previous committed site) or goes back when idle. Z, shoulder buttons, or the wheel switch between regional and landmark views. The playtest uses a separate profile; normal save files and normal startup are unchanged.

## Western Marches corridor

Marches Camp connects to Greyhollow Mine in real relief terrain. The Road into the Marches is available only after the existing rescue and campaign gates. Travel follows the authored road, not straight lines between 2D positions. Arrival saves the waypoint; opening the briefing and confirming deployment are separate actions. The authored route continues from Road into the Marches over the north timber bridge to Marches Crossing. The south ford is visible geography but not a selectable overworld shortcut. At the mill, open the existing Grain on Credit briefing, or select the return sign to retrace the road. Marches Road Camp appears after the Greyhollow rescue and acknowledged reveal. From Road into the Marches you can march down a short spur and open its own Operations screen, including existing Combat Drills and Unit Progression. On reload the campaign resumes at the existing Road junction, not a new save ID. This update does not add a new battlefield, optional encounter, or XP award. Campaign positions beyond Marches Crossing still use the existing campaign map in this review build.

The references are the original [Xbox manual pp. 20–21](https://www.manualslib.com/manual/378779/Games-Microsoft-Xbox-Kingdom-Under-Fire-Heroes.html?page=11) and captured Heroes gameplay showing the [tilted route view](https://www.youtube.com/watch?v=_zjlYq3E9DM&t=800s), [settlement interface](https://www.youtube.com/watch?v=_zjlYq3E9DM&t=10560s), and [optional battle branch](https://www.youtube.com/watch?v=_zjlYq3E9DM&t=10920s). Torn Asunder's terrain, buildings, user interface and navigation assets are original. The useful patterns are map-first composition, clear road/destination states, place-specific services and a separate briefing.

## Extension checks

Keep the same world graph and save IDs when extending the 3D map. Build the next travel sectors and stock boundary transitions before switching normal startup. A forward camp should materialize after its owning campaign's confirmed story condition. Optional encounters need a separate, idempotent rewards ledger and a meaningful camp spend that benefits the next mission, not a replay or fake story clear.

After import, run `godot --headless --script res://tests/marches_crossing_authored.gd` for Crossing or `godot --headless --script res://tests/campaign_overworld_authored_title.gd` for the original route and 2D fallback. Normal controller/device render performance and wider world coverage still need verification. See the [corridor audit](audits/marches-overworld-development-v1.json) and [forward camp integration audit](audits/marches-road-camp-development-v1.json) and [Crossing integration audit](audits/marches-crossing-development-v1.json) for scoped evidence.

