# Combat system

In *Torn Asunder*, the player commands allied formations and fights as a hero in the same real-time 3D battle. The battlefield keeps running as the player switches views, and formations continue carrying out their orders while the player controls the hero.

## Battlefield command

Hold **L2** to pull the camera back and issue orders. Select an allied formation and order it to move to a position, attack an enemy, or hold its ground. Release **L2** to return to the hero camera. See the [DualSense controls](controls.md) for the full layout.

The command camera shows formations, routes, elevation, and lines of sight. Terrain shapes which orders are effective. Infantry can hold a narrow road, archers can cover an approach from a ridge, and cavalry needs enough open ground to build momentum and clear the enemy after a charge. Woods can provide cover from ranged fire.

## Hero combat

From behind the hero, the player uses light and heavy attacks, guards, dodges, and calls on an officer ability. The hero can also interact with mission objectives. Nearby troops keep fighting as the engagement changes. A support formation coming under pressure or a friendly unit arriving to reinforce the hero can change when to press the attack, hold, or pull back.

## Unit HP and damage

A platoon contains individual units with their own HP pools and combat ratings. The platoon health bar uses the combined maximum HP of its roster as its full width. Green is the HP of surviving units, red is the HP those survivors have lost, and black is the maximum HP of dead units. If one of ten equal-HP units dies and another drops to half health, the bar is 85% green, 5% red, and 10% black. When the wounded unit dies, its entire share becomes black.

### Damage formulas

The eight combat ratings are **Melee Power, Ranged Power, Fire, Lightning, Ice, Nature, Holy, and Curse**. Each starts at 1. Combat ratings are whole numbers clamped to the range of 1 to 100.

```text
Resolved component = max(0, base damage) × (100 + attacker's rating) / (100 + 0.2 × defender's rating)
Total damage       = sum of resolved components × attacker's level factor² / defender's level factor
HP lost            = min(target's current HP, total damage)
```

Each component uses the attacker's and defender's ratings for its own damage type. A point in a rating contributes its full value to attack and 20% of its value to defense. As both ratings rise together, the same hit deals more damage. Across the full supported rating range, ratings can scale each component to between 84.17% and 199.60% of its base damage. The level factor then applies to the combined damage. HP retains fractional damage between hits, and a hit can remove only as much HP as the target has left.

Tune ordinary attacks to keep full-health opponents of the same level from dying in one hit. A large level advantage can make a single hit lethal. These formula examples use a level factor of 1 to isolate the effect of ratings.

| Base HP damage | Attacker rating | Defender rating | Resolved HP damage |
|---:|---:|---:|---:|
| 0.50 | 1 | 100 | 0.42 |
| 40 | 50 | 50 | 54.55 |
| 40 | 20 | 1 | 47.90 |
| 40 | 100 | 80 | 68.97 |
| 40 | 80 | 20 | 69.23 |
| 40 | 20 | 80 | 41.38 |
| 40 | 100 | 1 | 79.84 |
| 40 | 1 | 100 | 33.67 |
| 2,500 | 90 | 10 | 4,656.86 |

A flaming arrow with 60 base Ranged damage at 75 versus 25 deals 100 HP of Ranged damage. Its 40 base Fire damage at 20 versus 80 adds 41.38 HP. The hit resolves to 141.38 HP before the remaining-HP cap. A target with 42 HP loses 42 HP and dies. The displayed examples round to two decimal places.

### Health and unit progression

A standard unit starts with 1,200 HP and gains three times as much HP per level as it did on the previous curve. The level factor scales same-level damage in proportion to that increase. Skill point purchases affect only the selected combat rating.

```text
Levels gained R       = L − 1
Reference HP factor B = (100 + R) / (100 + 0.2 × R)
HP factor H           = 1 + 6 × (B − 1)
Maximum HP at level L = starting HP × H
Level factor          = H / B
XP to advance from L  = 100 + 25 × (L − 1)
```

At equal levels, the multiplier on damage reduces to a single level factor. The share of HP lost per hit depends on the two builds and their level. Across different levels, a higher-level attacker gains damage and a higher-level defender reduces incoming damage.

XP carries across level thresholds. The first level-up costs 100 XP, level 98 to 99 costs 2,525 XP, and a unit reaches the cap at 128,625 total XP. Each new level automatically increases maximum HP and awards one banked stat point. Living units gain the same amount of current HP and keep their existing wounds. Spending one point raises the chosen combat rating by 1. From a starting rating of 1, a level-99 unit can reach 99 by spending all 98 earned points on a single rating.

These examples use regular Human Infantry's 37-base sword hit. Both soldiers are the same level and spend every earned point on Melee Power.

| Unit level | Standard maximum HP | Damage per hit | Hits to defeat |
|---:|---:|---:|---:|
| 1 | 1,200.00 | 37.30 | 33 |
| 20 | 2,254.34 | 69.96 | 33 |
| 50 | 3,770.49 | 116.82 | 33 |
| 99 | 5,919.73 | 183.14 | 33 |

At level 99, splitting points across five ratings gives each of the three most-trained ratings a value of 21 and each of the other two a value of 20. When both soldiers have Melee Power 20, it takes 47 sword hits to defeat one soldier. When both have Melee Power 1, it takes 54.

Open **Unit Progression** from a campaign briefing to award XP and allocate points on a practice unit. The practice unit is temporary. Campaign XP rewards will be connected when playable missions are added.

## Platoon training

Each skill has ranks from 0 to 5 and governs its own part of an engagement. **Cohesion** measures how well a platoon is holding together on a scale of 0 to 100. Charge impact, casualties, and rallying affect cohesion.

| Skill | Combat effect |
|---|---|
| **Charge & Brace** | A charge starts with 24 points of cohesion damage and gains 8 per rank. A braced defender absorbs 8 points plus 6 per rank of its own Charge & Brace before Formation Drill applies. |
| **Mounted Training** | Divides the time a mounted platoon needs to turn, set up a charge, or regroup by `1 + 0.15 × rank`. |
| **Formation Drill** | Divides cohesion loss by `1 + 0.12 × rank`. Each casualty starts at 22 points of cohesion loss. Reforming recovers 7 points per second plus 3 per rank. |
| **Scouting** | Increases sight range from 48 m by 8 m per rank in open terrain and from 24 m by 5 m per rank when the target is in cover. Detection requires a line of sight. |
| **Siegecraft** | Divides the crew's 12-second setup time by `1 + 0.15 × rank` and its 8-second reload time by `1 + 0.10 × rank`. Accuracy starts at 50% and gains 8 percentage points per rank. |
| **Beast Handling** | War beasts obey at 60 cohesion or higher at rank 0. Each rank lowers that threshold by 8 points. Rallying restores 3 cohesion per second plus 2 per rank. |

Combat Drills is available from every campaign briefing. Select a skill to compare its training ranks against rank 0, or select Curse to compare combat ratings of 1, 20, 40, 60, 80, and 100 against rating 1. The drills run the combat rules in controlled scenarios, including charging and bracing, reforming after a casualty, scouting through cover, and trading Curse hits. Campaign battles are planned for a later milestone.

## 3D battlefield presentation

Both cameras show the same 3D map, environment, units, and animations. From above, unit animations should make it clear when a formation braces, loses cohesion, or rallies. At ground level, attack windups, gaps in the formation, and approaching reinforcements should be visible in time for the player to react.

## Year One battle at the mine

The opening battle of the [five-year war](lore.md#the-five-year-war) uses the same terrain across three campaigns. Each faction has a different reason to engage or withdraw.

- **Humans.** Order shield infantry to hold the road and archers to cover the ridge while the hero escorts the Godbridle down the pass. When an Orc company intercepts the escort, fight at ground level while the infantry and archers continue their orders.
- **Orcs.** Tie down the escort with one company while another reaches the miners who can explain what happened to the river.
- **Druids.** Use the clash at the pass to buy time to evacuate the miners through the tunnels.

## Human Infantry promotion

Human Infantry qualifies for Heavy Infantry at **Melee Power 10**. With the standard ratings this means spending nine earned stat points on Melee Power, so level 10 is the earliest possible unlock. Unspent points, other ratings, and Battle Points do not count. The eligibility check does not spend points.

Provisional profile for testing: Heavy Infantry would retain its ratings and trade sword damage and mobility for staying power. It has 1,320 starting HP instead of 1,200 and deals 32 base damage with a basic sword hit instead of 37. Its provisional running speed is 85% of regular Infantry’s (2.295 m/s vs. 2.7 m/s). In Mara’s **Unit Progression** practice session, qualifying Infantry can equip the Heavy profile without losing XP, ratings, or unspent points. **Inspect 3D Model** opens the current unit in the studio. Leaving the practice session discards the temporary unit; promotion practice does not change the campaign save or any skirmish build. Run `godot --headless --script tests/infantry_promotion.gd` and `godot --headless --script tests/infantry_promotion_menu.gd` after importing the project to test the gate, damage tradeoff, and practice flow.

The AI Skirmish setup offers Infantry and Heavy Infantry for each platoon. Heavy Infantry requires Melee Power 10. All soldiers in that platoon use its selected HP, sword damage, and running speed; ratings and training still use the regular Infantry rules. Refunding Melee points or lowering the level below the requirement switches the build back to Infantry without reallocating points. Regaining the required rating does not reselect Heavy Infantry. Heavy soldiers use their own model, ready pose, run, cut, and guard clips. States without authored reactions or cheers reuse the Heavy ready pose. A defeated Heavy soldier is hidden until a death clip exists. Run `godot --headless --script tests/heavy_infantry_skirmish.gd` and `godot --headless --script tests/heavy_infantry_skirmish_menu.gd` for mixed-roster, eligibility, and model-selection checks.

References for the design pattern only: [*Kingdom Under Fire: Heroes* manual, pp. 20–25](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf) for skill-gated jobs and [official Human unit guide](https://www.kufheroes.com/eng/characters/unit_human.asp) for the slower heavy armor role. Torn Asunder uses its own combat profile and has no additional Lightning modifier for this promotion.

## Human Archer prototype

`HumanArcherVolley` is a combat component, not yet a roster entry, battlefield order, or model. An archer trades staying power for a **3.5–52 m** firing band: **960 starting HP**, **52 base Ranged damage**, **0.70 s** to draw and **1.90 s** to reload. It cannot fire while engaged in melee; getting pinned after starting the draw interrupts it and forces a reload. These numbers are provisional.

A controller queries admission, selects one opposing target, and supplies current 3D foot positions, melee pressure, and a terrain/cover query. The draw locks the target. At release the component rechecks distance, visibility, and whether it is still the same living enemy. The battlefield can show a progress bar from the exposed phase and return a reason for a blocked shot. Height matters through the lane to the target, not a separate high-ground damage bonus. Shots use the ordinary Ranged rating and level rules, and only actual HP loss credits up to **4 Battle Points** to the supplied team pool.

Run `godot --headless --script tests/human_archer_volley.gd` for timing, target, and Mine terrain checks. The [official *Kingdom Under Fire: Heroes* Human unit guide](https://www.kufheroes.com/eng/characters/unit_human.asp) is precedent for a ranged role that loses its bow attack when tied up in melee; Torn Asunder has its own range, damage and timing.
