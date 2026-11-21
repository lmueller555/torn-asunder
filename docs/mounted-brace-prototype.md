# Mounted pass and anti-riding brace prototype

This is a standalone combat rule and development playtest, not a new unit, character asset or change to any campaign encounter. The [official *Kingdom Under Fire: Heroes* Human unit guide](https://www.kufheroes.com/eng/characters/unit_human.asp) and [original Xbox manual's cavalry entry](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf#page=14) inspired the broad relationship: mounted units want space to charge, and a specialist can hold against a frontal approach. Torn Asunder's values and rules below are its own.

- **Mounted pass:** The command commits to a straight lane ending beyond the target. Riders earn a run-up only by moving. At contact the path must be reachable, the opponents must share clear contact, and enough open ground must remain for a run-out. Obstacles, an elevation break, a short run-up or a blocked exit prevent the impact. Mounted Training uses the existing setup and regroup scaling.
- **Brace:** An Anti-riding line must Hold, remain still and keep its facing long enough to prepare. Turning, moving, releasing Hold or dropping below the cohesion threshold removes protection. Both the contact point and the rider's incoming direction must be in the front arc; a riding unit can feint, go around, or wait for the defender to move.
- **Resolution:** Terrain and runway checks come first. Against a live frontal brace, riders lose cohesion and stop at contact; defenders take only the existing braced charge impact, never an ordinary hit on top. Otherwise the charge hits once and continues toward its ordered endpoint. Later terrain can stop the run-out without undoing or repeating the impact. Both use 'Charge & Brace' and 'Formation Drill' through `CombatPlatoon`. This prototype does not invent an HP damage rating, grant Battle Points, or add a roster branch.

## Try it on the Well Road

Run `godot game/battlefield/mounted_brace_playtest.tscn` (or F6 on the scene). The playtest reuses the existing Red Basin battlefield and debug formations; it is not in the Campaign Vault.

- **East approach:** Hold **L2 / Shift** for command. Aim east with the left stick, WASD, or mouse. Press **Cross / H** to hold and face the cursor. Once the brace reads **READY**, press **R1 / G** to send the riders down the road. They must reach the line before it can repel them.
- **West approach:** Press **D-pad right / 2** to stage riders on the other end. Hold facing east again to see a charge breach a ready line from behind. Hold facing west instead to repel them. Use **Square / right click** to Move out of the lane entirely; moving drops the brace.
- **Covered wash:** Press **D-pad right again / 3** to stage the obstructed approach. Send the riders and watch the terrain stop them before contact. **Options / Backspace** resets the current drill. **R3 / M** switches to the wider command overview.

The scene observes the infantry’s actual pose and explicit Hold, then advances the mounted formation against the existing movement and clear-contact terrain queries. There are no default attacks, extra units or campaign rewards.

```sh
godot --headless --script tests/mounted_brace_encounter.gd
godot --headless --script tests/mounted_brace_playtest.gd
```
