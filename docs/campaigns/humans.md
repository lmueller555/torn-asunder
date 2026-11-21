# Human campaign: The King's Water

King Mara Halden sends a royal detachment to save miners under Dryad attack. They do not know what the workers found until after the rescue. Later, Mara promises water as the price of allegiance and discovers that having the Godbridle lets him make a promise he cannot control. The campaign opens at Greyhollow around the midpoint of the [shared war timeline](../war-timeline.md#six-campaign-windows) and ends after the harbor rises at Moonwash. Mara makes the political decisions; the player commands his detachment and its field hero.

This document describes the story target. Today's playable mine escort does not implement the Greyhollow rescue or its reveal.

## Mission order

| Mission | Year | Unlock |
|---|---|---|
| Get Them Out | Three | Start Mara's campaign |
| Grain on Credit (`mara_grain_crossing`) | Three | Clear the rescue and show the discovery cutscene |
| The High Quay (`mara_moonwash_quay`) | Three | Clear Grain on Credit, then see Mara's command to Orrun |

Defeat restarts the mission with no unlock or change to the shared history. Preserve the active campaign's clear and debrief results; replaying an earlier chapter does not silently rewrite them. The last clear completes the campaign. The Year Four handover is not playable as Mara.

## 1. Get Them Out

**Briefing.** Dryads are attacking the Greyhollow mines. Workers are cut off from the road. Mara orders the detachment to rally at the south tunnel entrance, hold an escape route, and get the miners to safety. Neither Mara's briefing nor the mission's dialogue, objective text, or visible markers identify the Godbridle.

**Victory.** Rally at the south `TunnelEntrance`. Screen the miners as they flee south through the tunnel and then west to `MinerEvacuation`. The required miners must reach this safe point. Clearing enemy formations or bringing the hero out alone does not complete the rescue. **Defeat:** the hero falls or the rescue can no longer be completed. The battle does not require finding, inspecting, picking up, or carrying a relic.

**Teach: hold a route long enough for people to use it.** Keep the road pinch point, mine approaches, and ridge from the existing battlefield. Shield infantry can hold the pinch point and archers can cover movement from the ridge. Telegraph the Dryad pressure so the player can move the screen as the miners come through. These are tactics, not extra win conditions. The same movement and Human breakthrough are visible in the [Dryad finale](dryads.md#finale-greyhollow-mines--year-three).

**Victory cutscene: What They Brought Out.** After the last required miners reach safety and the rescue succeeds, a miner tells the detachment what the crew found underground and reveals the Godbridle. This is the first confirmation for the Human campaign; do not put it in the briefing or play it on a lost or abandoned attempt. The cutscene does not make the artifact a reward the player must pick up on the battlefield.

**Transition.** After the reveal, the workers test the bridle by asking for water, Orrun wakes enough to answer, and the camp spring and the Red Basin's dry river follow. Mara takes custody. Sova's evacuation and Raska's agreement with a witness happen after the water test, when the workers need to leave the mine area altogether, not during the initial flight from Dryad attack. The rest of Mara's campaign can introduce their testimony in a report instead of replaying either encounter.

## 2. Grain on Credit

**Briefing.** Mara now has the Godbridle under his seal. The miner’s account and Sova’s survey connect the spring to the Basin’s dry river. Grain bought from an allied crown is on the far bank. Rival levies want to impound it before it reaches Mara's towns; the allied crown is already threatening to recall its grain and troops unless Mara makes good on water. Two loads can get through: seed grain to the mill yard by the bridge, and bread grain to a town store above the lower ford. The battle is over this shipment, not the ownership of the crossings.

**Victory.** Get at least one of the two carts intact to its marked receiving yard. Resolve as soon as both arrive, or when one has arrived and the second is destroyed or ordered to turn back. **Defeat:** the hero is defeated before resolution, or both carts are lost or turned back before either arrives. Reaching a yard ends threats to that load. Display one status per cart and let the player turn back an exposed cart so an already earned victory cannot stall.

**Teach: keep a reserve for the second lane.** The bridge route is short but exposed; the ford route is slower but screened from the far-bank archers. Show which route a rival levy is moving toward before it commits and keep enough space at the road fork for a held infantry formation to reinforce either lane. The player can gamble on a split escort or secure the urgent load first. Do not spawn enemies behind carts without warning or force both deliveries to advance at once.

**Result and transition.** Show the delivered loads in the next council briefing: seed means a planting can go ahead, bread means a town keeps its ovens open that week. Losing either load changes the petition read to Mara, not whether he speaks to Orrun. Even both carts cannot sustain a second failed harvest. With his allies threatening to pull their support, Mara asks Orrun to return water to the dry headwater channels. A judge asks whose water could fill them. Mara believes his precise wording will protect the neighbors; the scene ends before anyone knows what Orrun will move.

## 3. The High Quay

**Briefing.** Mara sends his detachment to Moonwash to find where the reversed current began and warn the harbor pilots. On arrival, buried walls push up beneath moored ships. The lower quay fractures, the flagged upper stairs are still passable, and Ilyra's pilots are rigging lines to crews stranded on stone. The detachment has orders to pull back, not to claim the harbor or fight the fleet.

**Victory.** Get the hero and surviving members of both royal platoons through the upper-quay exit. A platoon counts as extracted once its surviving members cross, and cannot be ordered back. **Defeat:** the hero falls or either platoon is wiped out before reaching the exit. Ilyra's rescue is not owned by the Human objective controller; it proceeds independently. The exit never closes, and hazard phases must leave an accessible inland route so a survivor cannot be stranded by the script.

**Teach: withdraw in bounds.** A local levy orders armed outsiders off the lower stair to reserve it for townspeople fleeing the quay. It presses the detachment uphill without entering Ilyra’s rescue lane. Give the player a safe landing above it: one platoon holds the narrow stair while the other moves to that landing, turns to cover, and then brings the rear guard up. Telegraph sinking or buckling slabs with visible cracks and a retreat warning before a lane is cut. The Elven rescue lane at water level is marked separately and is not a shortcut or a target. Do not require defeating the levy. Use a fixed shared post-rise layout; temporary unsafe floor zones are enough to show the harbor settling.

**Result and ending.** The detachment gets out with firsthand testimony and leaves the waterline to Ilyra, who continues her rescue rather than pursuing the bridle. In the last scene, Mara lays two reports beside one another: ships are still stranded, and water reached some Marches but missed others he pledged it to. An ally asks him to speak again. He leaves his seal on the case and orders it shut. The result acknowledges soldiers and supplies saved without implying that the harbor can be put back, every field received water, or Mara gave up custody this year.

## Map and implementation handoff

- **Greyhollow:** One geography, two battles: the rescue shared with the Dryads, and the later departure shared by the Orcs and Druids. Preserve the road, ridge, and tunnel outlet. For the rescue, use the south tunnel and west safe point with visible worker and safety states. Do not reuse the live pickup/exit sequence, relabel an artifact as a miner, or require wins in other campaigns.
- **Marches crossing:** One compact map with a fork, bridge, ford, and two receivers. The carts can follow authored paths; no campaign economy or supply simulation is required. The crossing layout can serve future Marches encounters with different orders.
- **Moonwash:** Build the exposed harbor walls, moorings, upper quay and exits as one shared layout for Human withdrawal and Ilyra's rescue. Use distinct starts and objective markers, not distinct harbor geometry. The Human point of view establishes the cost of the command; it doesn't play Ilyra's decision or award the player her rescue.


**Current campaign prototype (not the story target).** Mara's overworld still launches `mara_mine_escort` (“The Pass Below the Mine”), an artifact escort using `GodbridlePickup` and `GodbridleExit`. That clear still opens Grain on Credit, Road to Moonwash, and The High Quay in order. Existing mission/save IDs, dialogue, and objectives have not changed. The water request on the road is Mara's later command, not the miners' first test. The harbor runs the shared graybox and does not yet include levy combat.

**Acceptance for the new opening.** Play from a fresh Human save. Before rescue success, verify no objective, briefing, in-battle dialogue, or marker confirms the discovery. Try a lost or abandoned attempt and an exit without the miners; none should reveal the artifact or advance the campaign. On a successful rescue, verify the cutscene reveals the find only after the miners are safe and the next chapter unlocks. Check that replays cannot change the shared history.
