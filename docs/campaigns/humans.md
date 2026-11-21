# Human campaign: The King's Water

King Mara Halden promises water as the price of allegiance. He first proves he can keep the Godbridle, then discovers that possession lets him make a promise he cannot control. The campaign begins at the mine in Year One and ends at Moonwash in Year Two, within the [shared war timeline](../war-timeline.md#six-campaign-windows). Mara makes the political decisions; the player commands his royal detachment and controls its field hero.

## Mission order

| ID | Mission | Year | Unlock |
|---|---|---|---|
| `mara_mine_escort` | The Pass Below the Mine | One | Start Mara's campaign |
| `mara_grain_crossing` | Grain on Credit | Two | Clear `mara_mine_escort` |
| `mara_moonwash_quay` | The High Quay | Two | Clear `mara_grain_crossing`, then see Mara's command to Orrun |

These are stable design IDs under the existing campaign ID `mara`, not scene paths. Defeat restarts the mission from its briefing with no unlock or change to the shared history. Keep each successful clear and its debrief result for that campaign save. Replaying an earlier chapter does not reset or silently rewrite the active campaign's result. The last clear marks Mara's campaign complete; there is no playable Year Four handover here.

## 1. The Pass Below the Mine

**Briefing.** The Basin has lost its river, and an Orc company is already moving toward the road. Mara puts the Godbridle under his seal and orders the escort to bring it through the pass. The player does not yet have the workers' testimony or the dates from Sova's survey.

**Victory.** The hero takes possession at `GodbridlePickup`; the living carrier reaches the road boundary at `GodbridleExit` with the bridle. Reaching the exit before pickup or clearing the enemy without the artifact does not complete the mission. **Defeat:** the field hero is defeated before delivery. For the first slice, the hero is the only carrier; do not require a drop, handoff, Orc relic capture, or troop-survival quota.

**Teach: fix the enemy, keep the escort moving.** Use the [existing shared mine geography](../combat.md#year-one-battle-at-the-mine): shield infantry can hold the road pinch point and archers can cover it from the ridge. Give the player time to issue both orders. As the carrier approaches the pass, an Orc company intercepts; show the approach on the command view early enough to reposition. Return to the hero view for the break through the pass while the formations continue their orders. These are recommended tactics, not extra triggers the player must satisfy.

**Result and transition.** The royal seal reaches the Marches on the artifact, not on the workers. Outside the player's view, Sova gets the miners out through the tunnels, and one leaves willingly with Raska. In the debrief, a copy of her account reaches Mara: the spring and the dry river date to the same night. The next briefing jumps to the second bad harvest. Do not close the tunnel outlet, force the crew into Human custody, or show Raska taking the artifact.

## 2. Grain on Credit

**Briefing.** Grain bought from an allied crown is on the far bank. Rival levies want to impound it before it reaches Mara's towns; the allied crown is already threatening to recall its grain and troops unless Mara makes good on water. Two loads can get through: seed grain to the mill yard by the bridge, and bread grain to a town store above the lower ford. The battle is over this shipment, not the ownership of the crossings.

**Victory.** Get at least one of the two carts intact to its marked receiving yard. Resolve as soon as both arrive, or when one has arrived and the second is destroyed or ordered to turn back. **Defeat:** the hero is defeated before resolution, or both carts are lost or turned back before either arrives. Reaching a yard ends threats to that load. Display one status per cart and let the player turn back an exposed cart so an already earned victory cannot stall.

**Teach: keep a reserve for the second lane.** The bridge route is short but exposed; the ford route is slower but screened from the far-bank archers. Show which route a rival levy is moving toward before it commits and keep enough space at the road fork for a held infantry formation to reinforce either lane. The player can gamble on a split escort or secure the urgent load first. Do not spawn enemies behind carts without warning or force both deliveries to advance at once.

**Result and transition.** Show the delivered loads in the next council briefing: seed means a planting can go ahead, bread means a town keeps its ovens open that week. Losing either load changes the petition read to Mara, not whether he speaks to Orrun. Even both carts cannot sustain a second failed harvest. With his allies threatening to pull their support, Mara asks Orrun to return water to the dry headwater channels. A judge asks whose water could fill them. Mara believes his precise wording will protect the neighbors; the scene ends before anyone knows what Orrun will move.

## 3. The High Quay

**Briefing.** Mara sends his detachment to Moonwash to find where the reversed current began and warn the harbor pilots. On arrival, buried walls push up beneath moored ships. The lower quay fractures, the flagged upper stairs are still passable, and Ilyra's pilots are rigging lines to crews stranded on stone. The detachment has orders to pull back, not to claim the harbor or fight the fleet.

**Victory.** Get the hero and surviving members of both royal platoons through the upper-quay exit. A platoon counts as extracted once its surviving members cross, and cannot be ordered back. **Defeat:** the hero falls or either platoon is wiped out before reaching the exit. Ilyra's rescue is not owned by the Human objective controller; it proceeds independently. The exit never closes, and hazard phases must leave an accessible inland route so a survivor cannot be stranded by the script.

**Teach: withdraw in bounds.** A local levy orders armed outsiders off the lower stair to reserve it for townspeople fleeing the quay. It presses the detachment uphill without entering Ilyra’s rescue lane. Give the player a safe landing above it: one platoon holds the narrow stair while the other moves to that landing, turns to cover, and then brings the rear guard up. Telegraph sinking or buckling slabs with visible cracks and a retreat warning before a lane is cut. The Elven rescue lane at water level is marked separately and is not a shortcut or a target. Do not require defeating the levy. Use a fixed shared post-rise layout; temporary unsafe floor zones are enough to show the harbor settling.

**Result and ending.** The detachment gets out with firsthand testimony and leaves the waterline to Ilyra, who continues her rescue rather than pursuing the bridle. In the last scene, Mara lays two reports beside one another: ships are still stranded, and water reached some Marches but missed others he pledged it to. An ally asks him to speak again. He leaves his seal on the case and orders it shut. The result acknowledges soldiers and supplies saved without implying that the harbor can be put back, every field received water, or Mara gave up custody this year.

## Map and implementation handoff

- **Mine:** One battlefield for the Human, Orc, and Druid views. Keep the road, ridge, and tunnel outlet fixed. Only spawn positions, orders, and active objectives differ by campaign. The Human attempt can ship first using only the two named objective markers and hero defeat, even if formation orders and briefings are still being built.
- **Marches crossing:** One compact map with a fork, bridge, ford, and two receivers. The carts can follow authored paths; no campaign economy or supply simulation is required. The crossing layout can serve future Marches encounters with different orders.
- **Moonwash:** Build the exposed harbor walls, moorings, upper quay and exits as one shared layout for Human withdrawal and Ilyra's rescue. Use distinct starts and objective markers, not distinct harbor geometry. The Human point of view establishes the cost of the command; it doesn't play Ilyra's decision or award the player her rescue.


**Current campaign prototype.** All three Human missions are reachable through Mara's overworld. The first arrival on the Road to Moonwash after Grain on Credit presents the Water Request intermission; once read or skipped, it does not replay on revisits. At Moonwash Harbor, open the High Quay briefing before deploying. A successful withdrawal clears the third mission and marks the campaign complete on the map. The harbor playtest uses the shared large graybox and does not yet include levy combat.

Acceptance passes: try leaving the mine without the bridle and then with it; play the crossing with no deliveries, each single-load result, and both loads delivered; reverse which platoon leads the retreat at Moonwash. Verify only clears advance, all successful cart results can reach the same ending, and no Human objective can invalidate the Orc, Druid, or Elven account.
