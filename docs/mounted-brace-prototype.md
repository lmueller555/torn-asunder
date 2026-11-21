# Mounted pass and anti-riding brace prototype

This is a standalone combat rule, not a new unit, character asset or change to any campaign encounter. The [official *Kingdom Under Fire: Heroes* Human unit guide](https://www.kufheroes.com/eng/characters/unit_human.asp) and [original Xbox manual's cavalry entry](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf#page=14) inspired the broad relationship: mounted units want space to charge, and a specialist can hold against a frontal approach. Torn Asunder's values and rules below are its own.

- **Mounted pass:** The command commits to a straight lane ending beyond the target. Riders earn a run-up only by moving. At contact the path must be reachable, the opponents must share clear contact, and enough open ground must remain for a run-out. Obstacles, an elevation break, a short run-up or a blocked exit prevent the impact. Mounted Training uses the existing setup and regroup scaling.
- **Brace:** An Anti-riding line must Hold, remain still and keep its facing long enough to prepare. Turning, moving, releasing Hold or dropping below the cohesion threshold removes protection. Both the contact point and the rider's incoming direction must be in the front arc; a riding unit can feint, go around, or wait for the defender to move.
- **Resolution:** Terrain and runway checks come first. Against a live frontal brace, riders lose cohesion and stop at contact; defenders take only the existing braced charge impact, never an ordinary hit on top. Otherwise the charge hits once and continues toward its ordered endpoint. Later terrain can stop the run-out without undoing or repeating the impact. Both use 'Charge & Brace' and 'Formation Drill' through `CombatPlatoon`. This prototype does not invent an HP damage rating, grant Battle Points, or add a roster branch.

The model reads actual defender position, heading and Hold through `observe_defender` before stepping the riders. A future adapter supplies formation-footprint movement and contact queries in the same battlefield coordinates; the headless test uses the existing Well Road geometry for an open road and a blocked approach into the wash.

```sh
godot --headless --script tests/mounted_brace_encounter.gd
```
