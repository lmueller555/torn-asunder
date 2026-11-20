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

A standard unit starts with 1,200 HP. Levels gained determine the automatic HP curve and the level factor for damage. Skill point purchases affect only the selected combat rating.

```text
Levels gained R       = L − 1
Reference HP factor B = (100 + R) / (100 + 0.2 × R)
HP factor H           = 1 + 2 × (B − 1)
Maximum HP at level L = starting HP × H
Level factor          = H / B
XP to advance from L  = 100 + 25 × (L − 1)
```

At equal levels, the multiplier on damage reduces to a single level factor. The share of HP lost per hit depends on the two builds and their level. Across different levels, a higher-level attacker gains damage and a higher-level defender reduces incoming damage.

XP carries across level thresholds. The first level-up costs 100 XP, level 98 to 99 costs 2,525 XP, and a unit reaches the cap at 128,625 total XP. Each new level automatically increases maximum HP and awards one banked stat point. Living units gain the same amount of current HP and keep their existing wounds. Spending one point raises the chosen combat rating by 1. From a starting rating of 1, a level-99 unit can reach 99 by spending all 98 earned points on a single rating.

These examples use a 40-base hit between equal-level units who both spend every point on the relevant rating.

| Unit level | Standard maximum HP | Damage per hit | Hits to defeat |
|---:|---:|---:|---:|
| 1 | 1,200 | 40.32 | 30 |
| 20 | 1,551.45 | 52.05 | 30 |
| 50 | 2,056.83 | 68.90 | 30 |
| 99 | 2,773.24 | 92.75 | 30 |

At level 99, splitting points across five ratings gives each of the three most-trained ratings a value of 21 and each of the other two a value of 20. When both units have a rating of 20, the fight takes 44 hits. When both use an untrained rating of 1, it takes 50 hits.

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
