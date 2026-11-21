# Torn Asunder

*Torn Asunder* is a fantasy strategy action game set during Vareth’s five-year war over the Godbridle.

## Run the menu

Use Godot 4.7. Open `project.godot` in the editor and press **F5**. From a terminal, import the assets once and launch the game from the repository root.

```sh
godot --headless --editor --import --quit
godot
```

Use a mouse, the arrow keys and Enter, or the DualSense D-pad and Cross to navigate. Escape or Circle returns to the title screen from a submenu.

New Game opens the Campaign Vault and its six leader portraits. Starting a campaign opens its briefing and writes one local save per leader. Continue opens the most recently played briefing, and Load lists every saved briefing. Settings saves fullscreen and reduced-motion preferences. Playable missions are planned for a later milestone.

Open **Combat Drills** from any briefing to compare the six platoon skills across training ranks and test Curse damage at different ratings. The **Battle Points Drill** lets you earn shared BP with practice charges and try casting Field Benediction with trained and untrained casters.

Open **Unit Progression** to award XP to a practice unit, inspect its HP growth, and spend the points it earns.

In King Mara Halden’s **Unit Progression** practice session, raise Melee Power to 10 to try Heavy Infantry without changing your campaign save. **Inspect 3D Model** opens the current practice unit in the studio. Select **Face** for a close-up. The editable Blender source is in `assets/source`, and Godot uses the exported GLBs in `assets/models`.

Open **Unit Test** from the title screen to inspect any unit with a model in the unit catalog. Pick an animation to play it, use **Pause** or **Restart** to check the motion, and switch views using the buttons below the preview.

Select **Unit Test → AI Skirmish** to set up Blue and Amber. Give each side one to four platoons of 32 Human Infantry. Select a platoon, choose its level (1–99), and distribute its points among the eight combat ratings. Every rating starts at 1. Each level after the first earns one point, and each point raises one rating by 1. All 32 soldiers inherit their platoon’s build. Use **Adjust by** to spend or reclaim one point, five points, or as many as the selected rating allows. You can leave points unspent. Lowering a level removes the most recent investments first if the allocation exceeds the new budget.

Choose **Start Skirmish** to watch the armies fight. **Restart** replays the same matchup from full health. **Back** returns to setup with both rosters ready to edit. Each platoon has its own HP bar, and each side shows its total survivors.

Free soldiers scan every 0.35 to 0.70 seconds, pick a random eligible enemy within 5 meters, and run over to try to engage. Each soldier can engage up to three opponents at separate positions around them. Runners steer around soldiers in their way and nudge them sideways. A soldier in the middle of a swing or guard is harder to move. When a scan finds no available target, the soldier follows the nearest enemy and idles at the edge of the fight until a slot opens or the enemy moves. The health bars show current HP in green, missing HP on survivors in red, and HP lost to casualties in black.

When the enemy Infantry are fighting or approaching dies or moves beyond the 6.5-meter pursuit range, they wait a random 0–7 seconds. They can still cheer, defend, and take hits during that delay. Once ready, they have an equal chance to resume normal targeting or reinforce. Reinforcing Infantry look within 50 yards and find the allies tied for the most incoming attackers, then pick randomly from the five farthest in that group. They run to the chosen ally and engage the nearest eligible enemy attacking that ally. If no ally needs help, the ally dies or loses its attackers en route, or the soldier arrives without an eligible opponent, they roll a fresh delay.

The Human Infantry has a four-second **Idle**, a 1.2-second **Walk**, and a 0.8-second **Run**. Walk and Run loop in place and match forward travel at 1.02 m/s and 2.7 m/s, respectively. **Sword Slash** advances up to 0.52 meters into an overhead cut and ends in guard. It plays at 1.4× speed in AI Skirmish and Unit Test, taking about 1.05 seconds. Its preview marks the start and finish on a fixed floor. **Restart** returns the Infantry to the starting mark.

The shield block starts with **Shield Raise**, stays up in the looping **Shield Guard**, and returns to the ready pose with **Shield Lower**. All three clips are available in **Unit Test**.

**Blocked Hit Stagger** starts and ends in Shield Guard. The shield gives first, then the Infantry shifts his weight rearward and settles back into guard.

**Sword Recoil** is the attacker's reaction to a blocked overhead slash. The blade rebounds as the elbow folds and the torso carries forward over the planted lead boot. The trailing boot steps up as the soldier returns to the same ready pose and position as the end of Sword Slash.

In the source clips, **Shield Contact** marks `0.70 s` in **Sword Slash** and `0.0 s` in both **Sword Recoil** and **Blocked Hit Stagger**. With 1.4× playback, the skirmish resolves the strike at `0.50 s` and starts both reactions there if it is blocked.

**Hit Stagger** is a reaction to an unblocked hit. The torso jerks back, the sword arm drops, and the rear boot catches the soldier's weight. In AI Skirmish, the soldier moves **0.78 meters directly away from the attacker** during the reaction. **Unit Test** previews the 0.9-second clip from ready on a marked floor.

**Backward Knockdown** starts from ready. The rear boot tries to catch the soldier, his knee folds, and his hips land before his upper back. He keeps his sword and shield in hand. In AI Skirmish, the fall moves the soldier **1.875 meters directly away from the attacker**. The 1.15-second clip holds a face-up pose at the end. In **Unit Test**, select **Restart** to return to the standing pose.

**Get Up** starts from the exact final pose and position of **Backward Knockdown**. The soldier rolls onto his shield side, braces on his forearm, and plants a boot to push up from a kneel. He keeps both weapons in hand and finishes in the ready stance. Select **Get Up** in **Unit Test** to preview the recovery from the floor.

In AI Skirmish, the hit that knocks the soldier down deals damage. The soldier is then invulnerable through the fall, time on the ground, and **Get Up**, plus another 0.5 seconds after standing.

**Death Fall** is the Infantry's defeat animation for zero HP. His knees buckle, his weight drops onto his sword side, and his sword arm goes slack. The 1.2-second clip holds the final side-lying pose. In **Unit Test**, use **Restart** to replay it from ready.

**Sword Cheer** is a 1.4-second sword thrust into the air. Infantry waiting at the edge of a full engagement occasionally cheer and return to combat when a target opens up. Once the fight has started, 0.75 seconds with no enemy within 5 meters of any surviving platoon member triggers three cheers per survivor, staggered across the platoon. If the enemy returns to range, Infantry resume combat. **Unit Test** also lets you preview the cheer on its own.

After importing the project, run the damage and progression checks with `godot --headless --script tests/damage_checks.gd`.

Run `godot --headless --script tests/platoon_balance.gd` to sweep level-legal platoon ratings, sample mixed attacks, and check full-health one-hit thresholds.

Run `godot --headless --script tests/infantry_skirmish.gd` to check engagement spacing, passing, reserve movement, simultaneous hits, and complete AI matches. Run `godot --headless --script tests/skirmish_setup.gd` and `godot --headless --script tests/skirmish_menu.gd` to check custom builds, battles, and the setup menu.

## Game design

- [Vareth and the Godbridle](docs/lore.md)
- [The leaders of Vareth](docs/leaders.md)
- [Combat system](docs/combat.md)
- [DualSense combat controls](docs/controls.md)
- [Unit art workflow, from concept to rig](docs/unit-art-workflow.md)
