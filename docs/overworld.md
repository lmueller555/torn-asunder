# Vareth 3D overworld

Mara's Human campaign uses the authored Marches and Moonwash maps from the ordinary title. Choose New Game → Humans, or Continue or Load an existing Human save. Ilyra’s Elven campaign, Sova’s Druid campaign, and Raska’s Orc campaign also use 3D from the ordinary title. Neris’s Dryad campaign also uses the authored 3D map. Sereth retains his existing presentation until the remaining route passes release checks. A missing or invalid Mara map package falls back to the original campaign map rather than replacing the save or advancing the story.

For map development only, the isolated playtest still uses a separate profile. From the repository root:

```sh
godot --headless --editor --import
godot --path . --script res://game/overworld/marches_overworld_playtest.gd
```

Choose New Game and Mara to see the opening and play Greyhollow. After the opening battle, or on Continue or Load, use the campaign map. Ordinary campaign play uses the existing profile and saved waypoints; no migration is required.

## Browse, preview and travel

On authored 3D maps, the gold ring starts at the army’s station. Move the left stick or mouse to browse freely. The gold dots lead back to the army, which stays put while you browse. Reachable destinations have green markers. Hover for the mission preview; if a route is locked, its preview shows the actual prerequisite. D-pad and arrow keys still snap between sites.

Press controller A or Enter, double-click the waypoint, or use the contextual button to confirm a live selection. On a local route, an army miniature marches along the road and the station updates only on arrival. Press B or Escape to cancel while traveling, or to go back when idle. With reduced motion, travel completes without the marching animation. Selecting a mission at your current station opens its existing briefing; it does not deploy the army without confirmation.

Use the shoulder buttons, Z, or the wheel to switch between the regional and close lenses. Steering outward at the edge of the close view widens to the regional lens. Transitions between separate authored sectors still use their named boundary choices rather than drawing a path through unbuilt terrain. The battle minimap and legacy campaign maps are unchanged.

The shared cursor and travel checks run in Godot smoke tests as `tests/overworld_compass.gd`.

## Western Marches corridor

Marches Camp connects to Greyhollow Mine in real relief terrain. The Road into the Marches is available only after the existing rescue and campaign gates. Travel follows the authored road, not straight lines between 2D positions. Arrival saves the waypoint; opening the briefing and confirming deployment are separate actions. The authored route continues from Road into the Marches over the north timber bridge to Marches Crossing. The south ford is visible geography but not a selectable overworld shortcut. At the mill, open the existing Grain on Credit briefing, or select the return sign to retrace the road. Marches Road Camp appears after the Greyhollow rescue and acknowledged reveal. From Road into the Marches you can march down a short spur and open its own Operations screen, including existing Combat Drills and Unit Progression. On reload the campaign resumes at the existing Road junction, not a new save ID. This update does not add a new battlefield, optional encounter, or XP award.

## Moonwash Coast

After clearing Grain on Credit, select **Road to Moonwash** at Marches Crossing and confirm. Tab or controller Y selects the sector route; Enter or A confirms. You can cancel before the arrival is committed. This is a sector change between two separately rendered landscapes, not a patrol path across unbuilt terrain.

The original Water Request opens after the Road arrival is saved. Finish or intentionally skip the dialogue, then follow the existing coast road to the Harbor's high land gate. Harbor's stock briefing and deployment still require separate confirmation. Returning to the Marches or revisiting the Coast does not replay an acknowledged dialogue. A failed arrival write leaves the party at the previous location; a failed dialogue acknowledgment leaves the gate in place and offers Retry Save.

The references are the original [Xbox manual pp. 20–21](https://www.manualslib.com/manual/378779/Games-Microsoft-Xbox-Kingdom-Under-Fire-Heroes.html?page=11) and captured Heroes gameplay showing the [tilted route view](https://www.youtube.com/watch?v=_zjlYq3E9DM&t=800s), [settlement interface](https://www.youtube.com/watch?v=_zjlYq3E9DM&t=10560s), and [optional battle branch](https://www.youtube.com/watch?v=_zjlYq3E9DM&t=10920s). Torn Asunder's terrain, buildings, user interface and navigation assets are original. The useful patterns are map-first composition, clear road/destination states, place-specific services and a separate briefing.

## Ilyra’s Moonwash and Spanwater

New Game opens Ilyra’s introductory scene and deploys her directly into **Hulls on Stone** at Moonwash Harbor. After the battle, the overworld connects the Harbor to the Moonwash scout camp. Her rescue clear opens the grounded route to Survey Shore and its existing **Two Shorelines** briefing. Her own Survey clear then opens a reversible sector transfer to Spanwater’s **south landing**. Selecting the berth and confirming deployment still opens the original Year Four evacuation. Transferring does not launch a mission or grant a victory. Ilyra’s Harbor result and saved waypoints are independent of Mara’s Upper Quay and Raska’s north-bank approach.

The Linux native launch check exercises an old Harbor save, actual coast navigation, cold Load at the south berth, cargo persistence, and a separate Mara Upper Quay load. [Scoped visual audit](audits/ilyra-overworld-v1.json).

## Sova’s Cairnspine

New Game keeps Sova’s original opening scene and deploys **The Workers’ Way Out** directly. Return from battle, Continue, or Load to see the authored overworld. Cairnspine Camp and the Greyhollow entrance share a physical route. Sova’s own mine evacuation clear unlocks the reversible Greyhollow–Assembly crossing. Select a named crossing with Tab or controller Y before confirming; it does not draw a road between separate landscapes.

At the Assembly, choose the original **Let Them Walk Out** briefing. After the hearing is cleared, travel the upper road to the existing Year Four Godbridle handover. The handover opens on arrival, or on a cold resume if it was left unread, and does not replay after a successful acknowledgement. The short final road leads to the closed Cairnspine Vault entrance and the Year Five **No New Command** briefing. Travel and save actions do not grant victories.

[Scoped Cairnspine visual audit](audits/sova-overworld-v1.json). No additional optional missions or battlefield assets are installed by this rollout.

## Raska’s Basin and North Spanwater

New Game keeps Raska’s original first scene and deploys **One Person to Ask** at Greyhollow directly. After battle, Continue, or Load, the 3D map presents the correct campaign stage. Use the named local crossings to travel between Basin Camp, the Greyhollow west shelf, and Basin Well Road. Raska’s own Mine Witness clear opens the Well Road crossing; his own **The Second Bucket** clear opens the way to Spanwater. These crossings save before switching sectors, and Cancel leaves the previous station and save intact.

The Year Four arrival for **River, Not Sea** is on Spanwater’s **north causeway**. It does not use Ilyra’s south landing, her evacuation gates, or her rescue outcome. [Scoped four-sector visual audit](audits/raska-overworld-v1.json).

## Neris’s Grove Road

New Game opens Neris’s existing opening and deploys **What We Planted Here** directly. After battle, Continue, or Load, the Grove Camp and Isolated Grove nursery are reached by their authored forest road. An existing Grove victory unlocks the route to the Cairnspine Boundary Post and **Where the Road Goes**. Neris’s own Survey clear opens a named, reversible crossing into her Year Three Greyhollow approach and **Before They Reach It**. Neris’s save remains separate from Mara’s, Raska’s, and Sova’s use of the mine.

The packaged Grove and Boundary relief share 54 indexed terrain tiles; two Boundary overrides are separate. The loading panel reports real preparation progress. Cancel restores the prior screen or station without advancing the save. A missing or invalid map package falls back to the canonical chart rather than using unreviewed terrain. [Scoped visual audit](audits/neris-overworld-v1.json).

## Extension checks

The Linux export preset includes both loose route-data files as well as late-loaded scene resources. The **Mara native overworld launch** workflow verifies export and normal title travel from a release executable, away from the source checkout. It checks new and resumed Human play in an isolated profile.

Keep the same world graph and save IDs when extending the 3D map. Verify all required routes, saves, and clean exported startup before making the 3D map the normal campaign view. A forward camp should materialize after its owning campaign's confirmed story condition. Optional encounters need a separate, idempotent rewards ledger and a meaningful camp spend that benefits the next mission, not a replay or fake story clear.

After import, run `godot --headless --script res://tests/marches_crossing_authored.gd` for Crossing or `godot --headless --script res://tests/campaign_overworld_authored_title.gd` for the original route and 2D fallback. For the coastal boundary and saved dialogue, run `tests/mara_sector_overworld_authored.gd` and `tests/mara_water_request_authored.gd`. Controller/device render performance and wider world coverage still need verification. Scoped visual evidence: [corridor](audits/marches-overworld-development-v1.json), [forward camp](audits/marches-road-camp-development-v1.json), [Crossing](audits/marches-crossing-development-v1.json), and [Moonwash](audits/moonwash-overworld-development-v1.json).


