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

Open **Combat Drills** from any briefing to compare the six platoon skills across training ranks and test Curse damage at different ratings.

Open **Unit Progression** to award XP to a practice unit, inspect its HP growth, and spend the points it earns.

In King Mara Halden's campaign, select **Unit Progression → Inspect 3D Model** to view the Human Infantry. Select **Face** for a close-up. The editable Blender source is in `assets/source`, and Godot uses the exported GLB in `assets/models`.

Open **Unit Test** from the title screen to inspect any unit with a model in the unit catalog. Pick an animation to play it, use **Pause** or **Restart** to check the motion, and switch views using the buttons below the preview.

The Human Infantry has a four-second **Idle**, a 1.2-second **Walk**, and a 0.8-second **Run**. Walk and Run loop in place and match forward travel at 1.02 m/s and 2.7 m/s, respectively. **Sword Slash** plays once and returns to the ready pose.

After importing the project, run the damage and progression checks with `godot --headless --script tests/damage_checks.gd`.

Run `godot --headless --script tests/platoon_balance.gd` to sweep level-legal platoon ratings, sample mixed attacks, and check full-health one-hit thresholds.

## Game design

- [Vareth and the Godbridle](docs/lore.md)
- [The leaders of Vareth](docs/leaders.md)
- [Combat system](docs/combat.md)
- [DualSense combat controls](docs/controls.md)
