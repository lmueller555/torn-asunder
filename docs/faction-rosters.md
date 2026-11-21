# Faction rosters and advancement

There are six distinct roster identities: **Humans, Orcs, Elves, Druids, Dryads, and Undead**. Different names, battlefield uses, and branching advancement paths should reflect who each faction is. A faction does not need a unit in every category. Leave intentional gaps instead of filling out a symmetry checklist, and do not treat one leader's prototype detachment as the whole faction.

## Unit labels

The public labels are **Ranged, Melee, Elementals, Casters, Riding, Anti-riding, Flying, Siege, and Elite Support**. Assign one primary battlefield family and add secondary tags only when they describe the unit itself. Engineering is secondary; an engineering-capable infantry unit is still an infantry unit. Carrying an officer who can cast a spell does not make the unit a Caster. Use Casters as the primary family when casting is the troop's main job, or as a secondary tag when the troop itself casts as part of another job.

**Siege is a battlefield function. Elite Support is roster standing.** Mark elite standing separately so it can coexist with any appropriate family. A conventional catapult or mortar is Siege without assuming it is elite. A wall-breaking siege beast could be both Siege and Elite Support; a mammoth with other battlefield functions can be Elite Support without Siege.

Reference analogues, not Torn Asunder roster additions:

- [*Kingdom Under Fire: Heroes*: Human units](https://www.kufheroes.com/eng/characters/unit_human.asp). Paladins combine infantry fighting and holy casting, so **Melee + Casters** describes the hybrid. Sapper work can be an **Engineering** tag. Catapult and Mortar illustrate conventional **Siege**.
- [Orc units](https://www.kufheroes.com/eng/characters/unit_orc.asp). The Scorpion's ability to destroy walls illustrates **Siege + Elite Support**; the Swamp Mammoth illustrates **Elite Support** without assuming a wall-breaking job.
- [Dark Elf units](https://www.kufheroes.com/eng/characters/unit_elf.asp). Cavalry Archers use mobile attacks, so **Riding + Ranged** captures their battlefield use better than treating them as just foot archers with a horse.
- [Elementals](https://www.kufheroes.com/eng/characters/unit_Elementals.asp). An elemental's nature can define the **Elementals** family even when the creature itself also casts. This does not imply that these creatures or their stats exist in Torn Asunder.

## Data contract and first slice

`game/combat/faction_roster.gd` provides stable unit and role keys, label filtering, and explicit directed advancement links. An advancement only connects units of the same faction, requires at least one valid stat gate, and must be available from the currently selected unit. Every listed minimum on that specific edge must be met. Combat ratings and platoon training ranks are read separately from existing systems; consulting a branch neither alters the unit nor spends resources. The graph may have alternatives but not cycles. An unfilled branch is not a promised promotion.

`UnitCatalog.faction_roster()` classifies the existing Human Infantry, Heavy Infantry, and Human Archer. It reads the existing Melee 10 gate from the Heavy Infantry catalog entry; no balance, art, UI, save, skirmish, or promotion behavior changes. Human Archer already has volley behavior, but is not added to the model inventory. The Orc, Elf, Druid, and Dryad starter trees below add metadata only. The Undead tree is not authored here.

### Orc starter tree: Red Basin companies

These are the formations already named in [Raska’s Well Road and Spanwater playtests](campaigns/orcs.md). The names describe troop jobs; the lower-town companies are an allegiance in the story, not a fourth class. **Provisional roster gates only:** the table adds no soldier profiles, damage, movement modifiers, promotions in a menu, or playable combat. It does not alter the campaign’s fixed formations.

| Unit key | Form and role | Advance from Basin Regulars | Tradeoff to test later |
|---|---|---|---|
| `orc_basin_regulars` | **Basin Regulars**, Melee | Starting unit | General-purpose infantry can shift screens and hold narrow approaches, but has no dedicated anti-charge or ranged role. |
| `orc_brace_infantry` | **Brace Infantry**, Anti-riding + Melee | Melee **5** and Charge & Brace **2** | Commit to a frontal hold against a run-up; turning or redeploying drops that protection. A charge can go around them on open ground. |
| `orc_basin_archers` | **Basin Archers**, Ranged | Ranged **6** and Scouting **2** | Cover a road or wash shoulder from sighted ground; lose the shot behind terrain and need infantry if pressed in melee. |

From Basin Regulars, meeting both sets of gates makes both choices eligible; neither branch can skip into the other. Ratings and training are checked separately. No Battle Points, hero XP, or art availability substitute for these minima. The [official *Kingdom Under Fire: Heroes* Orc guide](https://www.kufheroes.com/eng/characters/unit_orc.asp) informs the distinction between durable general infantry and a specialist that stops mounted advances. These names, roles and numbers are Torn Asunder’s; Basin Archers come from its own Well Road scenario.

### Elf starter tree: Moonwash shore and ship

The [Elven campaign](campaigns/elves.md) already fields a **Shore Detachment** on Survey Shore and **Shore Marines** and **Ship Archers** at Moonwash Harbor. The Landing Marines at Spanwater are a marine assignment, not a separate unit class. These **provisional roster gates** describe training choices, not upgrades applied to those battles.

| Unit key | Form and role | Advance from Shore Detachment | Tradeoff to test later |
|---|---|---|---|
| `elf_shore_detachment` | **Shore Detachment**, Melee | Starting unit | Screens a signal or approach without specializing in landing relief or shipboard coverage. |
| `elf_shore_marines` | **Shore Marines**, Melee | Formation Drill **2** and Scouting **1** | Scout the route and reform after changing screens. Best used at ramps, moorings and landward approaches, not as a fixed anti-charge line. |
| `elf_ship_archers` | **Ship Archers**, Ranged | Ranged **4** and Formation Drill **1** | Cover open moorings and boat approach lanes from a deck; harbor walls block their shots. They need a shore screen and cannot replace it. |

The Marine branch needs platoon training only, while the Archer branch requires both a combat rating and formation training. Being shipboard does not grant Riding. These rows introduce no ship classes, movement modifiers, assets, combat logic or live equipment changes.

### Druid starter tree: Cairnspine guards

The [Druid campaign](campaigns/druids.md) names the **Tunnel Guard** and **Outlet Screen** at the mine, and the **Shelf Guard** on the vault road. The hearing's North and South Perimeters and the vault's Side Guard are positions to hold, not extra troop classes. These guard units do not cast spells or gain a claim to the Godbridle; the Keepers' decision to send guards beyond the Cairnspine is separate from a training gate.

| Unit key | Form and role | Advance from Tunnel Guard | Tradeoff to test later |
|---|---|---|---|
| `druid_tunnel_guard` | **Tunnel Guard**, Melee | Starting unit | Hold the mouth while two groups stage in cover; moving the whole guard forward leaves that shelter unprotected. |
| `druid_outlet_screen` | **Outlet Screen**, Melee | Scouting **3** | Spot an approaching detachment before releasing workers and cover the outlet while they pass. Chasing the detachment would leave the exit unscreened. |
| `druid_shelf_guard` | **Shelf Guard**, Melee | Melee **6** and Formation Drill **3** | Hold a narrow shelf or screen the carrier at the forecourt. Pressure after a breach is hard to recover from in the cramped shelf lane; the side path still needs a separate screen. |

These are **provisional roster gates only**. They do not change detection ranges, combat, the fixed campaign rosters, or how consent and custody work. The Outlet Screen's gate is training-only; neither melee investment alone nor rank alone qualifies for Shelf Guard.

### Dryad starter tree: grove work-site and route escorts

The [Dryad campaign](campaigns/dryads.md) fields the **Loading Guard** for the grove transplant, the **Feeder Reserve** at Spanwater, and **Shelf Volunteers** on the Cairnspine passage. The Track Screen and Side Volunteers are assignments to particular lanes, not a second set of promotions. Unlike Sova's vault detail, the Dryad volunteers move with people and hand off to a safe terrace; they are not protecting a bridle bearer or holding the vault itself.

| Unit key | Form and role | Advance from Loading Guard | Tradeoff to test later |
|---|---|---|---|
| `dryad_loading_guard` | **Loading Guard**, Melee | Starting unit | Keep the yard open while the crew ties down the root sled, then shift the screen to the raised road. Covering one lane leaves less help in the other. |
| `dryad_feeder_reserve` | **Feeder Reserve**, Melee | Charge & Brace **1** and Formation Drill **2** | Relieve the maintenance-path screen so town workers can keep fitting boards; chasing off-lane leaves the workers exposed. The reserve protects the work, not the wheel or gate. |
| `dryad_shelf_volunteers` | **Shelf Volunteers**, Melee | Melee **3** and Scouting **2** | Scout ahead of the next escorted group and screen its route to the terrace. A blocked path still needs a fresh route or escort; the volunteers cannot protect both groups in separate places. |

These **provisional gates** do not change the fixed mission roster or unlock spellcasting, river engineering, or root crossings. The field troops protect the workers maintaining the feeder and the guides moving people along the pass. Neither branch grants authority to speak for another grove.

Run `godot --headless --script tests/faction_roster.gd`.
