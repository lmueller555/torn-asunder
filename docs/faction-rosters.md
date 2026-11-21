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

`UnitCatalog.faction_roster()` classifies the existing Human Infantry, Heavy Infantry, and Human Archer. It reads the existing Melee 10 gate from the Heavy Infantry catalog entry; no balance, art, UI, save, skirmish, or promotion behavior changes. Human Archer already has volley behavior, but is not added to the model inventory. The other faction rosters and new paths are not authored here.

Run `godot --headless --script tests/faction_roster.gd`.
