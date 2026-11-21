# Flying sortie and anti-air prototype

This standalone model is not a roster entry, a siege attack or a campaign order. The [official *Kingdom Under Fire: Heroes* Human unit guide](https://www.kufheroes.com/eng/characters/unit_human.asp) and the [original Xbox manual’s aerial-unit entry](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf#page=14) inspire separate aerial and ground-attack roles, cover and ranged counterplay. The ranges, timing and resolution rules here are Torn Asunder’s own.

- **Fighters intercept aircraft.** They approach a fixed firing gate and need a clear shot to a still-in-range enemy fighter or bomber. They cannot use this order against ground units.
- **Bombers attack ground troops.** They commit to an overflight instead of firing from standoff range. Ground troops can move out from under the pass or into canopy. At release, any overhead cover vetoes the attack, even if a physics ray would pass through noncolliding foliage.
- **Defenders can break the pass.** An eligible fighter, or a ground unit explicitly equipped to shoot at aircraft, can answer while the sortie approaches. It must be ready, within its 3D range and have its own clear line of sight. An ordinary Ranged rating is not sufficient. A valid response damages the flyer and aborts the sortie before release, including when both reach their gates on the same step.

The caller supplies live target/defender poses, a terrain query for flight/shot segments, and an overhead cover query for a bombing target. The bomber and fighter both use ordinary CombatUnit Ranged ratings and actual HP loss. No points, XP, splash, squadrons, siege setup/ammunition, or flight AI are added. Each instance resolves one pass only.

```sh
godot --headless --script tests/flying_sortie.gd
```

The test uses the existing Marches forest canopy meshes for overhead cover and the existing terrain adapter for physical sight checks. No map or art changes.

## Try the development playtest

Run `godot game/battlefield/flying_sortie_playtest.tscn` (or F6 on the scene). Text markers on the existing Marches battlefield show the flyer, target and escort. The HUD reports cover, response readiness and actual HP loss.

- **1 / Bombing:** Press **G / R1** to launch. Stay in the clearing for a hit, or move a short distance left with **A / left stick** while the bomber approaches. Stop when the HUD says **Canopy**; the leaves can protect you without moving out of the pass.
- **2 / Ground anti-air:** Hold **H / Cross** while stationary to ready the equipped defender. In clear range, it drives off the bomber before release. Moving drops the response, so you can give up the shot and fall back into cover instead.
- **3 / Fighter interception:** Launch to intercept the airborne target. Move the target away from the lane to evade; the fighter will not follow.
- **4 / Fighter escort:** Move the escort into position, then hold **H / Cross** to defend the bomber. The escort still needs range and sight.

**D-pad left/right** cycles the drills. **Backspace / Options** resets the current one. There is no campaign entry or production art. Verify the actual scene and controls with `godot --headless --script tests/flying_sortie_playtest.gd`.
