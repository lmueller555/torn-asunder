# Moonwash Harbor: campaign-scale Year Two graybox

[The High Quay](campaigns/humans.md#3-the-high-quay) and [Hulls on Stone](campaigns/elves.md#1-hulls-on-stone) can both use `res://game/battlefields/moonwash_harbor_campaign.tscn`. The [small Moonwash graybox](moonwash-harbor-map.md) remains unchanged. The new scene is the same fixed **post-rise** harbor, set into a larger coastal headland and inland causeway. It does not stage the rise or run either mission.

```sh
godot tests/moonwash_harbor_campaign_preview.tscn
godot --headless --script tests/moonwash_harbor_campaign.gd
```

The preview opens above the battlefield. In the Godot editor, select the saved `HumanQuayView` or `ElvenDeckView` camera to inspect the two starts closer to ground level.

## Human withdrawal playtest

Run `godot game/battlefield/mara_moonwash_playtest.tscn` to try Mara's standalone withdrawal on the same geometry. Guide the hero and both royal platoons to the upper exit. Hold L2 to direct a platoon to the stair landing, move the others up, then bring the covering formation out. If warned about the lower stair, units still below can take the signed inland bypass. The lower stair only closes after an allied unit reaches the landing, the gate itself is empty, and the shared inland route is still passable. One local levy patrol walks the lower quay. It only reacts to a nearby living unit it can actually see; breaking sight and moving away returns it to the patrol. A formation on Hold can screen it, or the whole detachment can use the inland bypass before being spotted. Physical contact blocks movement but does not resolve damage. Ilyra's rescue is not part of this mission.

The live input checks are `godot --headless --script tests/mara_moonwash_playtest.gd` for withdrawal and closure and `godot --headless --script tests/mara_moonwash_levy.gd` for contact and a no-contact bypass.

## Tactical geography

Local coordinates are meters, **+X east**, **−Z inland**, **+Z seaward**. The suggested active command bounds are **288 × 242 m**, with headlands framing the west and east edges and the inland gate breaking the north escarpment.

- **Human withdrawal:** The detachment starts on the lower quay (Y=2.8). The flagged stair has two smooth collision flights, a defensible landing, and shoulders that narrow the approach. This is the shorter route, about **225 m** to the high exit. The inland bypass (about **344 m** from the rear guard) avoids both possible closure footprints, including from the hero and vanguard approaches. The high quay (Y=10.8) has cover beside the route and a dedicated causeway entrance. The levy uses the upper landward lane; it is not sent through the Elven pier.
- **Elven rescue:** The receiving deck (Y=1.6), the outer pier and gangways give the hero a **200 m** physical route to the stranded deck (Y=3.4) without crossing a rigging gap or using the Human exit. The raised wall breaks a real ship-to-shore sightline toward the screened mooring. The open east angle is still clear. Forward and aft rigging points lie **79.5 m** apart; each faces a paired receiver about **21 m** away across open water. No static plank permits crews to shortcut either rescue.
- **The shared coastline:** Solid quays and headlands contain land movement; the edge of each tagged floor gives way to water or a retaining wall. Water and foam are visual only. No swimming, moving sea, line rigging, scripted closure, combat, or rescue traffic exists in the terrain scene.

## Integration contract

All [small-map marker paths](moonwash-harbor-map.md#scene-contract) work unchanged. Resolve relative to the scene instance and use `global_position` after adding it to the tree. `Markers/PhaseZones/FracturedSlab` and `LowerStairClosure` are independent inert footprints; `box_size` remains full extents.

The command harness can use `Rect2(-144, -118, 288, 242)` and sector camera mode. Collision layer 1 is solid; supported surfaces, ramps and both ship decks are also tagged layer 2. The decks use static collision bodies so the command terrain adapter can pick them. Both future mission controllers can use the same geometry but decide and resolve their own events independently.
