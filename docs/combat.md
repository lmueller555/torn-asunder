# Combat system

In *Torn Asunder*, the player commands allied formations and fights as a hero in the same real-time 3D battle. The battlefield keeps running as the player switches views, and formations continue carrying out their orders while the player controls the hero.

## Battlefield command

Hold **L2** to pull the camera back and issue orders. Select an allied formation and order it to move to a position, attack an enemy, or hold its ground. Release **L2** to return to the hero camera. See the [DualSense controls](controls.md) for the full layout.

The command camera shows formations, routes, elevation, and lines of sight. Terrain shapes which orders are effective. Infantry can hold a narrow road, archers can cover an approach from a ridge, and cavalry needs enough open ground to build momentum and clear the enemy after a charge. Woods can provide cover from ranged fire.

## Hero combat

From behind the hero, the player uses light and heavy attacks, guards, dodges, and calls on an officer ability. The hero can also interact with mission objectives. Nearby troops keep fighting as the engagement changes. A support formation coming under pressure or a friendly unit arriving to reinforce the hero can change when to press the attack, hold, or pull back.

## Unit HP and damage

A platoon contains individual units with their own HP pools and combat ratings. The platoon health bar uses the combined maximum HP of its roster as its full width. Green is the HP of surviving units, red is the HP those survivors have lost, and black is the maximum HP of dead units. If one of ten equal-HP units dies and another drops to half health, the bar is 85% green, 5% red, and 10% black. When the wounded unit dies, its entire share becomes black.

The eight combat ratings are **Melee Power, Ranged Power, Fire, Lightning, Ice, Nature, Holy, and Curse**. Every rating works on both sides of a hit. Multiply each damage component by the attacker's matching rating multiplier and divide it by the defender's. The multiplier is `1 + 0.10 × rating`, with ratings from 0 to 5. Add the results and subtract the total from the target's HP. For example, an arrow that carries a curse resolves its impact with Ranged Power and its curse with Curse.

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

Combat Drills is available from every campaign briefing. Select a skill or Curse, then change the rank to compare the outcome against rank 0. The drills run the combat rules in controlled scenarios, including charging and bracing, reforming after a casualty, scouting through cover, and trading Curse hits. Campaign battles are planned for a later milestone.

## 3D battlefield presentation

Both cameras show the same 3D map, environment, units, and animations. From above, unit animations should make it clear when a formation braces, loses cohesion, or rallies. At ground level, attack windups, gaps in the formation, and approaching reinforcements should be visible in time for the player to react.

## Year One battle at the mine

The opening battle of the [five-year war](lore.md#the-five-year-war) uses the same terrain across three campaigns. Each faction has a different reason to engage or withdraw.

- **Humans.** Order shield infantry to hold the road and archers to cover the ridge while the hero escorts the Godbridle down the pass. When an Orc company intercepts the escort, fight at ground level while the infantry and archers continue their orders.
- **Orcs.** Tie down the escort with one company while another reaches the miners who can explain what happened to the river.
- **Druids.** Use the clash at the pass to buy time to evacuate the miners through the tunnels.
