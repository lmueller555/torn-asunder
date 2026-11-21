# Authoring mission events

A battle should change because something happened on the field: a carrier reached a pass, an enemy closed an outlet, or a cart made it to safety. Give the player a visible cue and a meaningful next order. Don't use time since deployment to summon a new threat, or turn an escort into a requirement to kill every enemy. If a closing window matters, show what is closing it and how to intervene.

The [original Xbox manual, pp. 12–15](https://manuals.plus/m/77bff80c4c8a7cc0c78419ed521a33be6d31fa0b7551d7ecba9d3abc949bc5a2.pdf#page=8) shows mission-specific information, troop ranges, and explored terrain in tactics view. An [Ellen playthrough, §4.17, Glaucus](https://www.supercheats.com/xbox/walkthroughs/kingdomunderfireheroes-walkthrough01.txt) records a battle that moves from an initial fight to a marked location, then an engineering objective with trap clearance and a floodgate. The useful precedent is the change in orders caused by events, not the exact encounters.


## Scale and interception

Use one of five battlefield sizes. Size means a normal infantry platoon's unopposed march between playable terrain edges, along a real route on the field. These are planning targets, not mission timers or limits on roads, detours or mounts.

| Size | Target march time | Planning distance at 3 m/s |
|---|---:|---:|
| Compact | 90 s | 270 m |
| Small | 110 s | 330 m |
| Standard | 130 s | 390 m |
| Large | 155 s | 465 m |
| Expansive | 180 s | 540 m |

Pick a plausible through-route using edge markers. March with the real formation and terrain adapters, with no combat or waiting, and record both measured time and route length. A rectangle, an objective-only route, or the length along a blocked straight line is not a scale measurement. The [tier helper](../../game/battlefield/battlefield_march_scale.gd) reports the nearest target while flagging marches outside the 90–180 s band separately. This sets all five targets; it does not claim an authored map exists for each class.

### Measured examples in current development maps

| Nearest class | Normal infantry benchmark | What the measurement covers |
| --- | --- | --- |
| Compact | [Marches Crossing](../marches-crossing-map.md#measured-march-scale): 290 m / 96.67 s | West to east ridge foot over the timber bridge. |
| Small | [Year One Mine](../year-one-mine-campaign-map.md#measured-battlefield-size-small): 326.9 m / 109.02 s | Supported passage between two physical rims, in both directions. |
| Standard | [Still Kingdom Cut](../still-kingdom-cut-map.md#geography-and-approach-choices): 390 m / 130.03 s | Open road between the live command limits. Terrain continues beyond both limits. |
| Large route | [Red Basin Well Road](../red-basin-well-road-map.md#operational-march-in-the-deployed-mission): 443.1 m / 147.8 s | Covered wash to the command limit, not the physical shelf edge. The same endpoints via the exposed salt road take 107.3 s, so the larger class describes this route, not the field as a whole. |
| Expansive | Not verified in a live deployment | Target remains 180 s, with a supported and tactically useful through-route. |

Use two different pressure modes: a **patrol** follows its lane and pursues only on confirmed sight within its local range, so screened routes stay meaningful; an **intercept** receives a specific route/order from a mission event and can put a formation in the player's path even before it sees them. Telegraph the latter and give the player room to respond. Never enlarge all global sight ranges simply to make larger maps feel occupied. Check both modes with actual cover, the [detection rules](../patrol-detection.md), and distinct player choices to engage, screen, or detour.

## Current contracts

### Mara — The Pass Below the Mine

- **Trigger:** The existing [escort model](../../game/battlefield/mine_escort_objective.gd) accepts a hero interaction in the pickup zone. On a later, nonterminal escort tick, `carrier_in_interception_approach` emits `interception_requested` once. The scene must report the living allied carrier, not a formation crossing the same area.
- **Cue and decision:** The [large Mine](../year-one-mine-campaign-map.md) stages one Orc road guard at `EastReserve`. A living carrier reaching the `PassRelease` approach triggers the HUD warning, then that same guard advances through `InterceptMouth` to `InterceptRoadMerge`. Put Shields in its path, reposition and fire with the working allied Archers, or push through with the carrier. A southern reserve or scripted enemy archer response would be additional work, not an effect of the existing guard or the allied Archer controls.
- **End and retry:** A living carrier's delivery wins without defeating the interception. Hero defeat or definitive bridle loss takes priority over same-tick delivery; no fresh warning is emitted on a terminal tick. Test the exit before pickup, lingering and re-entering the approach, and a fresh pickup and interception after restart.

### Sova — The Workers’ Way Out

- **Trigger:** In the [evacuation model](../../game/battlefield/sova_mine_tunnels.gd), the mouth group starts staged and the bend group reaches cover before it can be ordered out. Release a staged group through an open outlet. A moving group pauses if that outlet is blocked and resumes or reaches safety after it clears.
- **Cue and decision:** The [playable prototype](../../game/battlefield/sova_mine_evacuation.gd) labels both groups and Druid safety and shows when Sova can release a nearby group. Keep the second group under cover while checking the first group's route. The model supports blockage and failure; a hostile force that actually reports this pressure is not wired by that scene yet.
- **End and retry:** Both groups must reach Druid safety and the witness must be waiting under truce. The Orc rally is not a Druid objective. Test both release orders, a safety report before release, a block that clears, and a real loss or visibly closed outlet taking priority over a same-tick escape. Reset the group states and truce.

### Raska — One Person to Ask

- **Trigger:** The [playable prototype](../../game/battlefield/raska_mine_witness.gd) starts the Human detachment's advance when Raska comes within 10 m of the outlet. The [model](../../game/battlefield/orc_mine_witness.gd) requires an offer, Raska's interaction accepting the terms, and the other workers clear before escort starts. The current scene waits for the crew to clear before showing the offer; arriving alone at the rally cannot stand in for the witness.
- **Cue and decision:** The red detachment and marked approach make the closing window visible; the large map also shows its distance from sealing the outlet. Send Raska or a formation to screen the approach rather than chase Mara's carrier. Then accept the miner's terms and escort her to the Orc rally; consent is not a capture order.
- **End and retry:** The witness herself must reach the rally. Raska falling, loss of the witness, or a still-blocked outlet at the closing event overrides progress in the model. Test reaching the rally before consent or with the witness still behind, and reset the detachment, crew, offer, and escort on retry. The scene's screen mechanic is not a full combat/loss simulation.

### Mara — Grain on Credit

- **Trigger:** The [cart model](../../game/battlefield/mara_grain_crossing.gd) tracks separate dispatch, intact arrival at the cart's own yard, withdrawal, and definitive loss. A staged cart can't score an arrival; for an en-route cart, loss beats arrival and intact arrival beats a same-tick turn-back order.
- **Cue and decision:** The [logistics playtest](../../game/battlefield/mara_grain_crossing_playtest.gd) shows both cart states and a one-shot reserve cue when the first intact cart reaches `BridgeWestBank` or `FordWestBank`, not when it is dispatched. The bridge leads to the seed mill yard and the screened ford to the bread store. Use the [reserve fork](../marches-crossing-map.md) to cover both approaches or move toward the first crossing; turn back an exposed second cart if necessary. The [existing reserve](../../game/battlefield/marches_rival_reserve.gd) starts staged, actually marches to the chosen crossing, and blocks the cart’s path while unscreened. An allied formation must reach the contact area and Hold to screen it. This does not add a far-bank archer response or resolve reserve damage.
- **End and retry:** Both carts must resolve. One secured cart is enough; the result is `seed_only`, `bread_only`, or `both`. Two failed deliveries lose; hero defeat takes priority. Test both yards against the wrong cart, simultaneous loss and arrival, an idle second cart that can still be turned back, and a clean restart with both carts staged and no result.

## Before merging a new event

Keep the rule in the mission's existing Godot model and the cue, actors, input, and world positions in its scene. Evaluate one observation after movement, orders, and combat for that tick; make terminal outcomes sticky and make restart restore the model and the scene. Test early, repeated, and same-tick conflicting reports headlessly. In the scene, check that the cue appears before the consequence and is intelligible from either camera. Do not require a save or an objective clear from a different campaign to make a shared event happen.
