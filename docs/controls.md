# DualSense controls

The PlayStation 5 DualSense is the primary controller for *Torn Asunder*. Hold **L2** to enter the command view and release it to return to the hero. The battle continues in both views. See the [combat system](combat.md) for how the two views work together.

| Input | Hero combat | Command view while holding L2 |
|---|---|---|
| Left stick | Move the hero | Move the battlefield cursor |
| Right stick | Control the camera | Rotate and tilt the command camera |
| D-pad left / right | Cycle allied units for a quick status check | Select the previous or next allied unit |
| Square | Light attack | Order the selected unit to move to the cursor |
| Triangle | Heavy attack | Order the selected unit to attack the highlighted enemy |
| Circle | Dodge | Clear the current target |
| Cross | Interact with an objective | Order the selected unit to hold its current position |
| L1 | Guard | — |
| R1 | Use an officer ability | — |

At the mine, hold **L2**, select the archers with the **D-pad**, move the cursor over the Orc company approaching the escort, and press **Triangle**. Release **L2** to return to the hero while the archers carry out the order.

The first playtest should check whether the player can redirect a unit mid-fight and return to the hero in time to read the next incoming attack.

## Command harness playtest

Launch the standalone flat-field harness from the repository root with `godot game/battlefield/command_harness.tscn` (or open the scene in the editor and press **F6**). It has a placeholder hero and two allied formations. Try ordering the archers to cross the field, releasing L2 to move the hero while they march, then holding L2 again and ordering them to hold. Attack orders, hero combat, and campaign entry are not in this harness.

| Keyboard / mouse | Hero view | Command view while holding Shift |
|---|---|---|
| WASD | Move hero | Move cursor |
| Mouse | — | Aim cursor; left-click a formation to select it |
| Q / E; R / F | Orbit; tilt camera | Orbit; tilt camera |
| Z / X | Cycle allied status | Select previous / next allied formation |
| Right-click | — | Move the selected formation to the pointer |
| H | — | Hold the selected formation at its current position |

After importing the project, run `godot --headless --script tests/command_harness.gd` to check input, view changes, and order persistence.

To try the same controls on the shared Year One mine, run `godot game/battlefield/command_mine.tscn`. Formations take a straight path: if the path is blocked by solid terrain or cover, they stop and show **Blocked**. Issue a new Move around the obstruction. The main road is open, and the ridge is accessible via its ramps. To reach the overlook from the west, move the archers up the center of the ramp before turning toward the overlook. This is a movement playtest, not the escort objective or a combat encounter.

Run `godot --headless --script tests/command_mine.gd` to check the shared mine spawns, road and ridge movement, cursor picking, and blocking.

## Mara's mine escort prototype

Run `godot game/battlefield/mara_mine_escort.tscn`. Walk to the gold Godbridle marker, press **Cross** or **Space** in hero view, then carry it along the road to the marked east exit. **Cross** still issues Hold while L2 is down. Choose **Restart**, press **Options**, or press **Backspace** to try the route again.

One hostile road guard watches the east pass. When it raises its blade and **WINDUP** appears, face it and hold **L1 / U** to guard or dodge out of the swing with **Circle / L**. Move with the dodge for directional travel; without a direction, Mara dodges forward. **Square / J** is a quick light attack; **Triangle / K** winds up a stronger attack. Face the target and stay within reach until contact. Confirmed hits replenish team Battle Points, which start at 400 each attempt. The guard still attacks while you give orders, and Mara's defeat fails the escort.

In command view, select **Shield Infantry**, point at the highlighted road guard, and press **Triangle / K** to attack. Infantry follow the target into melee and keep attacking when you return to Mara. If cover blocks the direct approach, the infantry report **Blocked**. Move them around the obstruction and order the attack again, or use Hold to cancel. The prototype awards 6 team BP for each confirmed infantry contact. The guard can retaliate against attacking infantry if they are closer than Mara. Its windup shows who it is targeting, and the swing does not switch targets. Shield Infantry have a provisional shared health pool in this prototype. Defeated infantry cannot take further orders, but their loss does not fail the escort. With **Archers** selected, the same attack input starts a draw only from a clear, in-range lane. They stay where ordered instead of charging into melee. The readout shows draw, release and reload. If line of sight is blocked, reposition them before giving the attack again. If the guard reaches them, it can interrupt their draw and strike them; keep them behind infantry or on the ridge. Confirmed archer shots award 4 BP, and loss of the formation does not fail the escort.

This is a one-enemy combat prototype, not army-versus-army combat or campaign progression. Run `godot --headless --script tests/mara_mine_escort.gd` for the isolated objective route or `godot --headless --script tests/mara_mine_encounter.gd` for hero combat and enemy-caused failure. Run `godot --headless --script tests/mara_infantry_attack.gd` for the formation order and shared contact checks, or `godot --headless --script tests/mara_infantry_retaliation.gd` for targeting, defeat, and retry.

In the campaign-scale version, **R2 / V** winds up **Sundering Strike** in hero view. The HUD shows readiness and the **150 BP** cost. An accepted strike spends from the shared pool immediately, even if the swing misses; it does not earn BP back. Guard, dodge, other attacks, and command view do not queue or spend a denied strike. The campaign Mine starts with 400 BP. A fresh launch has a 700 BP cap; confirmed Human chapter clears can raise the cap on a later Mine replay. Retry restores 400 BP and keeps the cap set when you deployed. This affects the shared cap, not Mara’s attack ratings or HP. Run `godot --headless --script tests/mara_campaign_sundering.gd` for the live campaign input and contact check.

## Command camera on larger battlefields

On fields that enable the sector camera, hold **L2 / Shift** to start in a nearby tactical view. Move the cursor with the left stick or WASD; the camera follows once the cursor nears the edge of the view. With a mouse, move the pointer to a screen edge to pan. **R3 / M** switches to a map-wide overview; point at a place and press it again to inspect that sector. **L3 / Home** returns to the hero's sector. You can still select formations and issue orders from either command view. Releasing L2 / Shift returns to the hero without pausing orders.

This mode is opt-in through the command scene's `enable_sector_camera`, `field_bounds`, and `local_sector_size` settings. The current small prototypes keep their existing camera. Run `godot --headless --script tests/sector_camera.gd` to exercise both views and ordering on a synthetic 440 × 300 m field.

## Sereth’s command minimap at the Cut

In **The Names at the Cut**, hold **L2 / Shift** to show the north-up minimap. It shows Sereth, the two friendly guards, the selected platoon, and the area shown by the tactical camera. **Left-click** the minimap to center the camera without moving a platoon. **Right-click** a walkable point for one Move order. The Record Room roof rejects orders. The existing formation movement still checks obstacles on the way to a valid point.

On controller, hold **L2** and press **D-pad Up** to aim on the minimap. Use the **left stick or D-pad**, then press **Cross** for one valid Move. **Circle**, releasing **L2**, or losing focus cancels without an order. Outside minimap aiming, the usual stick, Move, and Hold still work. The map does not show raiders, queue waypoints, or appear in hero view. **Return to Campaign Map** remains usable while holding command. Verify the live campaign with `godot --headless --script tests/sereth_cut_command_minimap.gd`.

## Prototype platoon waypoints

The [original *Kingdom Under Fire: Heroes* Xbox manual, pp. 12–17](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf) describes issuing movement the same way with the minimap on and placing up to eight waypoints. Torn Asunder’s standalone queue keeps that limit. Both a tactical cursor and a minimap can supply the same battlefield XZ point and terrain check. A direct destination replaces the route, an appended waypoint extends it, and only reaching the next point consumes it. Duplicate or invalid requests leave the route intact. Hold or cancel must clear it explicitly.

Try route orders in the standalone flat-field scene: `godot game/battlefield/waypoint_command_harness.tscn`. Hold **L2 / Shift** for command, then press **R1 / G** to append the point under the terrain cursor. **Square / right-click** replaces the route; **Cross / H** clears it and holds. The selected platoon’s pending points are numbered in tactical view and in **R3 / M** overview. Orders keep advancing when you return to the hero. Campaign route queues are opt-in by mission; the Cut’s minimap sends single Move orders. Run `godot --headless --script tests/platoon_waypoint_queue.gd` to check the rules.

## Engagement camera policy

The standalone selection policy keeps three contexts distinct. An unengaged selected platoon uses the terrain cursor and tactical camera. Selecting a fighting ally follows that platoon without taking away formation orders. Selecting the fighting hero's platoon switches to direct hero action. An unrelated fight never steals the camera, and returning to tactical view keeps the previous cursor point.

Try the policy in the isolated development preview: `godot game/battlefield/engagement_camera_playtest.tscn`. Move Shield Infantry toward the **Practice patrol**: on contact, the camera follows the selected platoon and Square/right-click still issues Move. Cycle to the Hero Platoon and move it toward the **Sparring opponent**: on contact, the stick moves the hero and Square attacks. L1 guards and Circle dodges. Cycle to an unengaged platoon or leave contact to return to the saved tactical cursor. The opponents and formations use existing debug visuals; this tests controls, not final art or enemy combat AI.

While holding **L2 / Shift** in Mara’s campaign Mine, the local command camera gently follows selected Shield Infantry once they are in real melee contact. It leaves the cursor and orders in place; pointer or stick aiming, overview, and the minimap draft take priority. Release **L2 / Shift** to return to Mara’s unchanged direct controls. After importing, verify the policy with `godot --headless --script tests/engagement_camera_policy.gd` and the preview inputs with `godot --headless --script tests/engagement_camera_playtest.gd`.

In Mara’s campaign Mine, **D-pad Down / C** toggles camera focus on Mara without assigning an order. A focused Mara keeps the ordinary hero view until the living road guard is in clear melee reach, then the camera gently moves closer. The usual movement, orbit, attacks, guard and dodge still work. **L2 / Shift** always takes you straight to tactical controls, including the minimap and orders, even at contact. Explicitly cycling to an ally in command view or turning focus off clears the choice; while a minimap draft is open, **D-pad Down** nudges its cursor instead. Check the live interaction with `godot --headless --script tests/mara_campaign_lead_action.gd`.

## Mixed formation drill

Launch `godot game/battlefield/mixed_formation_drill.tscn`. Hold **L2 / Shift** for command, select Archers with **D-pad / Z X**, aim at the guard marker, and press **Triangle / K**. At the starting distance, the guard can close and pin the bow line before it releases. Use **Square / right-click** to fall back, then re-order the attack once the archers are clear and reloaded.

Reset with **Options / Backspace**. Move the archers farther back before issuing any attacks. Send Shield Infantry in first using the same attack command, then order the archers to fire while the guard is occupied. The same guard, melee, ranged and shared BP rules run in both attempts. The flat Command Harness is reused as-is for this opt-in development test; there is no new art or campaign entry. Verify with `godot --headless --script tests/mixed_formation_drill.gd`.
