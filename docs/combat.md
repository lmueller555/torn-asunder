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

The eight combat ratings are **Melee Power, Ranged Power, Fire, Lightning, Ice, Nature, Holy, and Curse**. Each unit has an integer rating from 0 to 100 for each type. An unspecified rating defaults to 0. Values outside the range are clamped to the nearest endpoint.

```text
Resolved component = max(0, base damage) × (100 + attacker's rating) / (100 + 0.2 × defender's rating)
Total damage       = sum of resolved components
HP lost            = min(target's current HP, total damage)
```

Each component uses the attacker's and defender's ratings for its own damage type. A point in a rating contributes its full value to attack and 20% of its value to defense. As both ratings rise together, the same hit deals more damage. At the widest rating gaps, a hit deals between 83.33% and 200% of base damage. HP retains fractional damage between hits, and a hit can remove only as much HP as the target has left.

Tune ordinary attacks to keep full-health opponents of the same level from dying in one hit. A large level advantage can make a single hit lethal.

| Base HP damage | Attacker rating | Defender rating | Resolved HP damage |
|---:|---:|---:|---:|
| 0.50 | 0 | 100 | 0.42 |
| 40 | 50 | 50 | 54.55 |
| 40 | 20 | 0 | 48 |
| 40 | 100 | 80 | 68.97 |
| 40 | 80 | 20 | 69.23 |
| 40 | 20 | 80 | 41.38 |
| 40 | 100 | 0 | 80 |
| 40 | 0 | 100 | 33.33 |
| 2,500 | 90 | 10 | 4,656.86 |

A flaming arrow with 60 base Ranged damage at 75 versus 25 deals 100 HP of Ranged damage. Its 40 base Fire damage at 20 versus 80 adds 41.38 HP. The hit resolves to 141.38 HP before the remaining-HP cap. A target with 42 HP loses 42 HP and dies. The displayed examples round to two decimal places.

### Health and unit progression

A standard unit starts with 600 HP. The target is roughly 15 hits from a 40-base-damage attack between units of the same level and rating. The HP curve uses a reference build that spends each level's +5 rating across five ratings, averaging one point per rating per level. The unit's real ratings come from where the player spends points.

```text
Reference rating R    = (L − 1) × 5 / 5
Maximum HP at level L = starting HP × (100 + R) / (100 + 0.2 × R)
XP to advance from L  = 100 + 25 × (L − 1)
```

XP carries across level thresholds. The first level-up costs 100 XP, level 98 to 99 costs 2,525 XP, and a unit reaches the cap at 128,625 total XP. Each new level automatically increases maximum HP and awards one banked stat point. Living units gain the same amount of current HP and keep their existing wounds. A point can raise any of the eight combat ratings by 5, up to 100. From zero starting ratings, the 98 points earned by level 99 can max four ratings and raise a fifth to 90.

| Unit level | Standard maximum HP | Damage at matched reference ratings | Hits to defeat |
|---:|---:|---:|---:|
| 1 | 600 | 40.00 | 15 |
| 20 | 687.86 | 45.86 | 15 |
| 50 | 814.21 | 54.28 | 15 |
| 99 | 993.31 | 66.22 | 15 |

Real builds spend whole points. Distributing them evenly across five ratings produces 15–16 hits across levels 1–99. Two specialists who both reach 100 in the relevant rating at level 21 take 11 hits. At level 99, two units using a rating of zero take 25 hits.

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

Combat Drills is available from every campaign briefing. Select a skill to compare its training ranks against rank 0, or select Curse to compare damage ratings from 0 to 100 in steps of 20. The drills run the combat rules in controlled scenarios, including charging and bracing, reforming after a casualty, scouting through cover, and trading Curse hits. Campaign battles are planned for a later milestone.

## 3D battlefield presentation

Both cameras show the same 3D map, environment, units, and animations. From above, unit animations should make it clear when a formation braces, loses cohesion, or rallies. At ground level, attack windups, gaps in the formation, and approaching reinforcements should be visible in time for the player to react.

## Year One battle at the mine

The opening battle of the [five-year war](lore.md#the-five-year-war) uses the same terrain across three campaigns. Each faction has a different reason to engage or withdraw.

- **Humans.** Order shield infantry to hold the road and archers to cover the ridge while the hero escorts the Godbridle down the pass. When an Orc company intercepts the escort, fight at ground level while the infantry and archers continue their orders.
- **Orcs.** Tie down the escort with one company while another reaches the miners who can explain what happened to the river.
- **Druids.** Use the clash at the pass to buy time to evacuate the miners through the tunnels.
