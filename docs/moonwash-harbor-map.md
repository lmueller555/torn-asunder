# Moonwash: shared post-rise harbor graybox

[The High Quay](campaigns/humans.md#3-the-high-quay) and [Hulls on Stone](campaigns/elves.md#1-hulls-on-stone) share `res://game/battlefields/moonwash_harbor.tscn`. The geometry represents the fixed harbor after the rise. Open and run `tests/moonwash_harbor_preview.tscn` with F6 for a lit, non-playable overview.

```sh
godot tests/moonwash_harbor_preview.tscn
godot --headless --script tests/moonwash_harbor.gd
```

## Reading the terrain

Coordinates are local meters, **+X east**, **−Z inland**, and **+Z seaward**. The colored water plane is visual only; it doesn't provide footing or swimming.

- **Human withdrawal.** The royal detachment starts on the cracked lower quay (Y=1.4). The flagged main stair runs through two flights and a broad landing to the high quay (Y=5.4); the west inland bypass and long ramp reach the same upper exit without the lower stair. The bypass avoids both optional unsafe-floor footprints, even from the starting marks. The levy can approach on the landward quay without entering the Elven lane. Stair treads are marked over smooth ramp collision.
- **Elven rescue.** A solid, raised wall interrupts the firing line toward the landward quay. The east mooring remains open. The low pier (Y=0.4) and its gangways let the hero, marines, and future salvage crews reach the mooring without using the upper exit. One ship is stranded on old masonry (deck Y=1.7); the receiving ship lies across open water (deck Y=0.8). Forward and aft have separate, paired endpoints. Both pairs span gaps with no static bridge. The outer pier and its gangways give the hero a way to reach both decks on foot without pre-rigging the rescue lines.

## Scene contract

Instantiate the same scene for either campaign. Resolve paths relative to the map instance; read marker `global_position` after adding it to the tree. Ordinary markers indicate standing positions at foot level. Terrain and hull collision are on layer 1.

| Relative path prefix | Marker names |
| --- | --- |
| `Markers/Spawns/` | `HumanHero`, `RoyalVanguard`, `RoyalRearGuard`, `LocalLevy`, `ElfHero`, `ShipArchers`, `ShoreMarines`, `ForwardCrew`, `AftCrew`, `ShoreSalvagers` |
| `Markers/Routes/` | `FracturedQuay`, `UpperStairFoot`, `UpperStairLanding`, `UpperStairTop`, `QuaySafeTurn`, `InlandBypass`, `InlandApproach`, `InlandStairTop`, `UpperQuay`, `LandwardRescue`, `OpenMooring`, `ReceivingGangway`, `StrandedAccess`, `StrandedDeckGangway`, `PierOuterTurn`, `PierInnerTurn` |
| `Markers/Objectives/` | `UpperQuayExit`, `ForwardTransfer`, `AftTransfer`, `ForwardReceiver`, `AftReceiver`, `ReceivingDeck`, `OptionalCargo` |
| `Markers/PhaseZones/` | `FracturedSlab`, `LowerStairClosure` |

Transfer and receiver markers sit on opposite ship decks: they are hooks for crew movement, not live triggers. Phase markers describe future footprints using `box_size` Vector3 metadata (full dimensions centered on the marker). No phase area has collision or closes a route yet. No actors, cameras, navigation mesh, changing coast, rigging, combat, or campaign state is part of the production scene. The walk and sightline tests cover representative geometry, not formation widths or mission outcomes.
