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
