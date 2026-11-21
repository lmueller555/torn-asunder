# Dryad campaign: Room to Grow

**Rootspeaker Neris Alder · Years One–Three · Ends at Greyhollow**

Neris believes a prophecy that says the world will end if Humans reach the Godbridle. She follows the warning before the bridle is found, traces a credible lead to the Greyhollow mines, and leads an attack to stop the Humans from reaching it. Her belief is sincere. The story does not tell the player that the prophecy is true or make the attack the only possible response to it. See [the Dryad groves](../leaders.md#dryads--rootspeaker-neris-alder) and the [shared timeline](../war-timeline.md).

This is the story target, not the route currently playable in Godot.

## 1. What We Planted Here — Year One

Use the isolated grove and nursery setup. A drought already threatens the grove, well before Orrun awakens or anyone diverts the river. Neris helps the grove move its first living tree to the nursery rather than force a root crossing under the town's wells. The people she helps have a reason to fear losing their home; that fear gives the warning weight without making it proof. Neris hears the prophecy and takes it literally. Other Dryads can take the danger seriously without agreeing that attacking people is justified.

## 2. Where the Road Goes — Year Two

At the Cairnspine Boundary Post, Neris physically surveys both existing routes. The carter is an ordinary traveler, not an oracle or secret agent. What the carter knows and what Neris learns by surveying the roads point her to Greyhollow as a plausible location. Neither the traveler nor the evidence confirms the Godbridle is there, that the workers have it, or that Orrun has awakened. As Rootspeaker, Neris can lead the volunteers who join her; she cannot give assent on behalf of every grove.

## Finale: Greyhollow mines — Year Three

**Briefing.** Neris believes she has run out of time. Her force attacks the mine approaches to stop any recovery, while Mara's detachment fights to reach the trapped workers. Keep the mine camp, approaches, ridge, and pass consistent with the [Get Them Out](humans.md#1-get-them-out). This is the same attack, not the later Orc and Druid encounter at the tunnel outlet.

**Turn and ending.** Give the player battlefield orders that carry out the Dryad attempt to hold the approaches. Even a well-fought stand cannot stop the rescue. Telegraph the Human breakthrough as a story turn, not an invisible timer or a fake “stop the rescue” win condition. The finale can be completed by getting Neris and her surviving force out after the breakthrough; a tactical clear acknowledges the withdrawal, not success in denying Human access. Never award an alternate ending in which the miners are killed, the rescue fails, or the Dryads seize the bridle.

**What the Dryads see.** The workers escape south through the tunnel, then west to safety. The attempt to deny access fails. End with that failure, not with a Dryad preview of the Human victory cutscene. The latter is where the workers show what they found. Neris does not witness the water test or Orrun's awakening here.

## What follows in the shared history

The later diversion puts the isolated grove's water supply under pressure again. The nursery Neris helped start in Year One still depends on the town’s feeder; the renewed drought did not cause the first transplant. Neris keeps the town's feeder open at Spanwater and helps civilians and witnesses reach the Cairnspine terrace while Sova returns the bridle. These events still happen. They are not extra chapters after the Dryad finale, and no other campaign needs a Dryad clear to proceed.

**Current development playtests (superseded as the main campaign route).** The existing overworld still links “What We Planted Here” (`neris_failing_grove`), “Water at the Town Gauge” (`neris_spanwater_feeder`), and “A Road We Can Share” (`neris_cairnspine_passage`). The grove setup is reused for Year One, with a different cause and briefing; the original feeder and vault-road levels remain available as historical playtests rather than new campaign chapters. This document does not claim the revised route is deployed. See the [implementation index](implementation-index.md) for current launch paths.

**Acceptance for the new route.** Verify that pre-discovery briefings show only what Neris can know. Play both Greyhollow perspectives from independent saves: the same workers get to safety, Humans reach the bridle, and the Dryad completion never claims the opposite. Only the successful Human rescue plays the discovery cutscene. Neither campaign requires the other to have been played.

## Legacy playtest reference

These scenario notes are kept for development and map references. The first is the original version of the grove setup; its old date and briefing are not the canon origin of the Year One drought. The feeder and vault-road events do not become playable chapters after Greyhollow.

### 1. What We Planted Here — Year Three (`neris_failing_grove`)

**Playtest:** Choose Neris, travel from Grove Camp to the Isolated Grove, and read “What We Planted Here” (`neris_failing_grove_dispatch`) before deployment. “Room for the First Tree” (`neris_failing_grove_debrief`) follows the successful transplant. That clear opens travel to the feeder battle at Spanwater Lock. Opening `game/battlefield/neris_failing_grove_playtest.tscn` directly runs the same battle without updating a campaign save.

**Briefing:** The river’s new cut has left the grove dry. The town offers a watered nursery plot if the grove helps keep the old feeder open. The grove withholds assent for the root crossing and asks Neris to help with its first transplant.

- **Map and orders:** A raised road joins the grove to the nursery. It is the only route wide enough for the root sled. A sunken track hides a second approach to the loading yard. Hold the road with one platoon and use the other to screen the track from a position with line of sight. The town’s existing well is visible beside the nursery and is neither a resource to spend nor an objective to seize.
- **Turn and win:** Neris speaks with the grove’s envoy, then uses the grove-side interaction to call the volunteer crew out from shelter. Keep the loading yard clear until they secure the first living tree on its sled. Change the lead platoon’s hold from the yard to the road before the crew moves. Reach the nursery and interact to help the crew settle the root ball. Show the difference between the stages: the loading cloth comes off in the yard; the tree stands upright in wet soil at the end.
- **Pressure and failure:** Armed foragers come for the yard’s dwindling water and threaten the road. When enemies enter the work zone, workers shelter and the current task pauses; clear the zone to resume it. Mark the exposed sled when the crew moves and let it stop under the screen rather than path blindly into enemy control. Fail if the sled is destroyed before the transplant or Neris falls.
- **Cost:** The nursery has room to start a transplant, not to move the whole grove at once. The volunteers return for the remaining trees later; the old planting place stays dry. Neris honors the refusal and commits crews to the feeder. The town’s offer is not permission for a new crossing.

### 2. Water at the Town Gauge — Year Four (`neris_spanwater_feeder`)

**Briefing:** Raska will open the spillway to the old Basin riverbed, leaving the sea gate shut. The first rush can bury the town feeder with silt. The nursery needs water through the feeder after the release, not just water visible in the main channel.

- **Map and orders:** Use the [same Spanwater Lock](orcs.md#3-river-not-sea--year-four-orc_spanwater_release) as the Orc campaign. The upstream approach, raised service causeway, lock controls, old riverbed crossing, and low landing keep their roles. The Dryad lane follows the feeder maintenance path; it reaches the feeder’s inlet rack and the downstream town gauge without going through the spillway controls or the landing.
- **Turn and win:** Interact at the inlet rack to clear its first blockage, then order a platoon to protect town workers as they finish fitting the feeder’s guide boards. Raska’s off-lane release starts at the same story beat regardless of player readiness, with a visible warning. As the main river rises, clear any fresh blockage at the rack and keep the maintenance lane open. Win when the main channel reaches river stage and continuous flow lifts the town gauge to its mark. Show water reaching the town end of the channel, not a capture banner.
- **Pressure and failure:** The low crossing becomes impassable after release; units can still reach either feeder station from the raised side. A debris pulse jams the feeder if the boards are unfinished, and March troops pressure the workers’ approach. Mark the jam, pause board work under enemy pressure, and allow either problem to be recovered before the crest. Fail if the crest buries the feeder before the boards are set and the rack is clear, or if Neris falls. Telegraph the crest in both views; it cannot occur before a baseline roster has a fair chance to finish the work.
- **Cost:** Neris stays with the feeder instead of sending the platoons after the Godbridle. Ilyra’s boats have their own evacuation lane; neither the boats nor an Orc victory screen is required. In the debrief the volunteers hand the working gauge over to the town, which keeps its wells and the nursery. Mara’s later handover does not put the bridle in Neris’s custody.

### 3. A Road We Can Share — Year Five (`neris_cairnspine_passage`)

**Playtest:** The town-gauge clear opens Cairnspine Vault Road. Read “A Road We Can Share” and confirm deployment. Screen the routes your groups take or reroute a waiting party, then bring both groups to the witness terrace to see “Room by the Stove” and complete the legacy playtest route. The vault ceremony and the other factions’ results are not prerequisites. Continue stays at the arrived waypoint; the finished battle remains replayable.

**Briefing:** The groves refuse a continent-wide crossing. Nearby groves separately send volunteers to keep people moving while Sova takes the bridle to the vault. Neris accepts those offers without reopening the question of the crossing.

- **Map and orders:** Start at the valley assembly and safe staging area at the foot of the pass. The narrow shelf leads toward the vault; a side path rejoins it at the forecourt. A safe terrace adjoining the forecourt is the Dryad destination. The artifact’s escort and the vault entrance are visible but not order targets. Clear and hold the route to the terrace, not the vault gate.
- **Turn and win:** Meet the local guide at staging to bring a refugee group forward on the cleared route; a second guide waits for Neris’s signal to bring the witnesses. In the command view, show which group is moving, waiting, or under pressure. At either marked decision point, confirm one clear route as Neris; threatened groups stop at the last safe marker instead of automatically entering melee. Win when both groups are confirmed safe at the terrace. The witnesses proceed later to attest the closure.
- **Pressure and failure:** A rival company advances along the shelf while a detachment threatens the side-path rejoin. A platoon holding the rejoin can keep the second route open while Neris guides the people already in motion. If either route is lost, recover it or use the other before the attackers reach a waiting group. Fail if either group is lost or Neris falls. Do not make Sereth’s stand against the court or Sova’s progress to the vault a hidden condition.
- **Cost:** The last volunteer group is committed to the witnesses, not a bid for the artifact. Close on the guides deciding which refugees they can take back with them. The nursery still needs tending. No root crossing is declared, no grove is bound by another grove’s answer, and Neris gives no command to Orrun.
