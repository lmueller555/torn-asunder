# Elven campaign: The Coast We Remember

Tide Speaker Ilyra Venn remembers the streets under Moonwash. The pilots who keep her fleet afloat know the living coast above them. Over [Years Two–Four](../war-timeline.md#six-campaign-windows), Ilyra learns what rebuilding her home would ask of theirs. The player commands her pledged ships and their shore detachments; unpledged ships are not hers to order.

## Mission order

| ID | Mission | Year | Unlock |
|---|---|---|---|
| `ilyra_moonwash_rescue` | Hulls on Stone | Two | Start Ilyra's campaign |
| `ilyra_coast_survey` | Two Shorelines | Three | Clear `ilyra_moonwash_rescue` and see Sova's disclosure in debrief |
| `ilyra_spanwater_evacuation` | Last Boat at Spanwater | Four | Clear `ilyra_coast_survey` |

These IDs belong to campaign `ilyra`, not particular scene files. Defeat retries the current mission without advancing the campaign. Save clears and their debrief results; replay does not overwrite the active campaign's results. The last clear ends Ilyra's playable campaign. She does not play the Year Five return to the vault.

## 1. Hulls on Stone

**Briefing.** Masts pitch as old walls rise beneath moored ships. Ilyra recognizes the corner of her childhood street beneath a stranded hull. One port signals that the pledged ships should pursue the artifact while the Marches are distracted. Ilyra keeps them in harbor and orders their crews to rig a rescue.

**Victory.** Secure the forward and aft transfer points in either order. At each, have the field hero rig a marked line and bring that stranded crew group across to the receiving deck. Win when both groups have landed. **Defeat:** the hero falls, or either required crew group is wiped out before delivery. Show crew and transfer status separately. Loading a marked cargo bundle is optional; no cargo objective blocks a crew transfer or the mission clear.

**Teach: use the ship and the shore together.** Shipboard archers can cover the open moorings but lose line of sight behind the newly exposed harbor wall. Put marines on the wall's landward approach while the hero rigs the sheltered transfer. Salvage crews close on abandoned cargo from the shore; do not make the Human detachment a target. Once a line is rigged, the hero can leave it to reinforce elsewhere. The crew pauses if its receiving point is contested and resumes when the approach is clear.

**Result and transition.** The fleet saves its crews and loads what cargo it can. Recovered cargo keeps a few boats supplied during the next survey; if it is left, their pilots borrow stores from the fishing villages instead. This is a debrief consequence, not a different set of unlocks. From a separate copy of Sova's public account, Ilyra learns why the old coast drowned. Her own memories tell her where to look; what she saw at the harbor tells her to count the people living there now.

## 2. Two Shorelines

**Briefing.** The ports ask Ilyra for a chart to support their claim that the old coast can be raised. She insists that it mark both the drowned streets and the working harbors that would lose their water. The pilot villages agree to help if their soundings are carried on the same chart. One port sends armed crews to seize the completed chart for its own delegation rather than circulate the village findings.

**Victory.** Take readings at the marked ancestral stone and the living fishing inlet, then relay both to the pledged survey cutter from either signal point. A reading is recorded when the hero inspects its marker. Raising the signal requires a clear line of sight to a marked stopping point on the cutter's loop and a secure position for one uninterrupted signal. **Defeat:** the hero falls before both readings are acknowledged, or the cutter is disabled before it acknowledges both. A broken or interrupted signal resets its progress, not the recorded readings. Do not permanently destroy both land signal points.

**Teach: plan for line of sight and the tide, not a kill count.** From the command view, show where headlands block signals and which shoal the cutter must skirt. The beach point can signal earlier but is pressured by landing crews; the headland point takes longer to reach but is easier to screen. Give an advance signal when the cutter is about to round the point, and let a missed pass cycle rather than soft-lock. The field hero takes the readings while a shore detachment defends the chosen signal point and ship support screens the exposed approach.

**Result and transition.** Ilyra circulates the complete chart instead of submitting a map that leaves out the working villages. At the Year Four briefing the ports still expect her to use the fleet to claim the Godbridle when a chance arises. The pilots have seen that Ilyra will put their testimony on the record, and volunteer to guide the shallow-draft boats up the new channel to Spanwater.

**Dialogue data.** `ilyra_coast_survey_dispatch` briefs the two readings and relay choice. A successful acknowledgment selects `ilyra_coast_survey_debrief_beach` or `ilyra_coast_survey_debrief_headland` by the final relay, not by the prior rescue's cargo. Both reports circulate the whole chart and earn the pilots' offer of help. An interrupted signal or defeat has no success debrief. In the development campaign, deploy at Survey Shore after clearing Hulls on Stone. A replay can show a different relay report without changing the first Moonwash cargo result.

## 3. Last Boat at Spanwater

**Briefing.** Households caught on the low bank can reach the river landing but cannot cross the fighting on the raised service causeway. Raska moves to open the spillway into the Basin's old riverbed; no one has ordered the sea gate opened. While the launches approach, several ports signal their pledged ships to break off and pursue the Godbridle convoy. Ilyra orders their launches to stay until the households are clear.

**Victory.** Embark both designated household groups at the low river landing and get their loaded launches through the marked boat exit. Count a group as safe only once its launch has crossed the exit; launch and group status stay visible until then. **Defeat:** the hero falls, a required household group is lost, an occupied launch is disabled before safety, or boarding ends while a required group is still ashore. Mark the last departure with a warning and a visible rise on the landing steps. Loaded boats already away can still finish after boarding closes.

**Teach: time a shuttle and hold the loading lanes.** Two launches approach on authored routes and only one can use the landing at a time. Send the closer households down under cover first, or start the farther group early while the nearby one shelters. At fixed, signaled points in the release, strong current makes the launch pause at a marked holding position before it can cross the outflow. Keep marines between the approaches and the landing while the hero meets the household group that is about to miss its boat. Ships cover the approaches from the water; they cannot shoot through the lock wall or stop the release. Holding the spillway controls, operating the sea gate, keeping the feeder open, or chasing the convoy cannot complete the Elven mission.

**Result and ending.** Ilyra carries the households out. The ports that ordered pursuit withdraw their pledges after the launches are clear. A departing captain asks who will take their place in the fleet. Ilyra asks him to take one family farther downriver before he goes. The debrief can show an Elven witness remaining for Mara's later handover to Sova, but does not promise that the Elves have won custody or that Ilyra has ceased to want her coast back.

**Dialogue data.** `ilyra_spanwater_dispatch` sets the evacuation order and `ilyra_spanwater_debrief` gives one account after both groups reach safety, regardless of boarding order or launch used. The captain’s later favor is not a mission objective. The dispatch and debrief are wired into the campaign, not the standalone scene.

**Standalone playtest:** Run `godot game/battlefield/ilyra_spanwater_playtest.tscn` on the shared campaign terrain. Use **Cross / Space** beside either household group. Hold Marines at the marked landing approach to push back the patrol. Boarding occurs at the sole berth; a launch can wait for the current to ease, and only crossing the boat exit saves its passengers. The rising steps visibly warn before boarding closes. **Options / Backspace** restarts. Existing unapproved graybox/debug visuals are reused for development with text actor markers; it adds no art, naval combat, or fluid simulation. Clear Two Shorelines to deploy at Spanwater in the Elven development campaign. Both groups must cross the boat exit to complete the campaign. The battle remains replayable without changing the first Moonwash cargo result, and a standalone launch does not update a campaign save.

## Shared maps and implementation handoff

- **Moonwash:** One post-rise layout for this mission and the [Human High Quay withdrawal](humans.md#3-the-high-quay). Reuse the exposed walls, moorings, stairs, and upper exit. The Elven receiving deck is on the water-level rescue lane already visible in the Human view. The Humans leave by the upper exit independently of rescue success. Do not require either campaign to fight or wait for the other.
- **Coast survey:** One short shoreline section. Obscure the cutter with terrain and use authored stop and pass points rather than simulating the tide. Boarding, rigging and signaling can use the same hero-interaction pattern as the mine pickup; moving boats can follow paths rather than requiring a player sailing controller.
- **Spanwater:** Keep the raised service causeway, spillway controls, old Basin riverbed, separate sea gate, feeder branch, and low landing/boat exit in the [shared battle](../war-timeline.md#where-perspectives-can-overlap). The same release sends water into the riverbed, not the old sea. Script it as a visible external phase change in Ilyra's mission; it does not depend on her commands. The Dryads can keep the feeder channel open while the boats leave; the custody handover remains separate from both actions.

Acceptance passes: rig the Moonwash points in either order and finish without cargo; interrupt a survey signal, recover on the next pass, and clear from either point; board the Spanwater groups in either order, verify both loaded boats must cross the boat exit, and test closing the landing with an empty or loaded boat in transit. Verify that no Elven clear changes the Human withdrawal, the Orc spillway outcome, or the Dryad feeder result.
