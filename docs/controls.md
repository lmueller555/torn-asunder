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

In command view, select **Shield Infantry**, point at the highlighted road guard, and press **Triangle / K** to attack. Infantry follow the target into melee and keep attacking when you return to Mara. If cover blocks the direct approach, the infantry report **Blocked**. Move them around the obstruction and order the attack again, or use Hold to cancel. The prototype awards 6 team BP for each confirmed infantry contact. The guard can retaliate against attacking infantry if they are closer than Mara. Its windup shows who it is targeting, and the swing does not switch targets. Shield Infantry have a provisional shared health pool in this prototype. Defeated infantry cannot take further orders, but their loss does not fail the escort. Archers still use only Move and Hold.

This is a one-enemy combat prototype, not army-versus-army combat or campaign progression. Run `godot --headless --script tests/mara_mine_escort.gd` for the isolated objective route or `godot --headless --script tests/mara_mine_encounter.gd` for hero combat and enemy-caused failure. Run `godot --headless --script tests/mara_infantry_attack.gd` for the formation order and shared contact checks, or `godot --headless --script tests/mara_infantry_retaliation.gd` for targeting, defeat, and retry.

## Command camera on larger battlefields

On fields that enable the sector camera, hold **L2 / Shift** to start in a nearby tactical view. Move the cursor with the left stick or WASD; the camera follows once the cursor nears the edge of the view. With a mouse, move the pointer to a screen edge to pan. **R3 / M** switches to a map-wide overview; point at a place and press it again to inspect that sector. **L3 / Home** returns to the hero's sector. You can still select formations and issue orders from either command view. Releasing L2 / Shift returns to the hero without pausing orders.

This mode is opt-in through the command scene's `enable_sector_camera`, `field_bounds`, and `local_sector_size` settings. The current small prototypes keep their existing camera. Run `godot --headless --script tests/sector_camera.gd` to exercise both views and ordering on a synthetic 440 × 300 m field.
