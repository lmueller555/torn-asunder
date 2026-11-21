extends RefCounted
## Authored conversations. A route may replay a beat without mutating its source.

const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")
const Moonwash := preload("res://game/battlefield/ilyra_moonwash_rescue.gd")
const Survey := preload("res://game/battlefield/ilyra_coast_survey.gd")

const MARA_MINE_DISPATCH := &"mara_mine_dispatch"
const MARA_MINE_DEBRIEF := &"mara_mine_debrief"
const RASKA_MINE_DISPATCH := &"raska_mine_dispatch"
const RASKA_MINE_DEBRIEF := &"raska_mine_debrief"
const RASKA_WELL_ROAD_DISPATCH := &"raska_well_road_dispatch"
const RASKA_WELL_ROAD_DEBRIEF := &"raska_well_road_debrief"
const RASKA_SPANWATER_DISPATCH := &"raska_spanwater_dispatch"
const RASKA_SPANWATER_DEBRIEF := &"raska_spanwater_debrief"
const RASKA_SPANWATER_CODA := &"raska_spanwater_coda"
const SOVA_MINE_DISPATCH := &"sova_mine_dispatch"
const SOVA_MINE_DEBRIEF := &"sova_mine_debrief"
const SOVA_PUBLIC_RECORD_DISPATCH := &"sova_public_record_dispatch"
const SOVA_PUBLIC_RECORD_DEBRIEF := &"sova_public_record_debrief"
const SOVA_GODBRIDLE_HANDOVER := &"sova_godbridle_handover"
const SOVA_VAULT_RETURN_DISPATCH := &"sova_vault_return_dispatch"
const SOVA_VAULT_RETURN_DEBRIEF := &"sova_vault_return_debrief"
const MARA_GRAIN_DISPATCH := &"mara_grain_dispatch"
const MARA_GRAIN_SEED_DEBRIEF := &"mara_grain_debrief_seed_only"
const MARA_GRAIN_BREAD_DEBRIEF := &"mara_grain_debrief_bread_only"
const MARA_GRAIN_BOTH_DEBRIEF := &"mara_grain_debrief_both"
const MARA_WATER_REQUEST := &"mara_water_request"
const MARA_HIGH_QUAY_DISPATCH := &"mara_high_quay_dispatch"
const MARA_HIGH_QUAY_DEBRIEF := &"mara_high_quay_debrief"
const ILYRA_MOONWASH_DISPATCH := &"ilyra_moonwash_dispatch"
const ILYRA_MOONWASH_CARGO_DEBRIEF := &"ilyra_moonwash_debrief_cargo_recovered"
const ILYRA_MOONWASH_CREWS_DEBRIEF := &"ilyra_moonwash_debrief_crews_only"
const ILYRA_COAST_SURVEY_DISPATCH := &"ilyra_coast_survey_dispatch"
const ILYRA_COAST_SURVEY_BEACH_DEBRIEF := &"ilyra_coast_survey_debrief_beach"
const ILYRA_COAST_SURVEY_HEADLAND_DEBRIEF := &"ilyra_coast_survey_debrief_headland"
const NERIS_FAILING_GROVE_DISPATCH := &"neris_failing_grove_dispatch"
const NERIS_FAILING_GROVE_DEBRIEF := &"neris_failing_grove_debrief"
const NERIS_SPANWATER_FEEDER_DISPATCH := &"neris_spanwater_feeder_dispatch"
const NERIS_SPANWATER_FEEDER_DEBRIEF := &"neris_spanwater_feeder_debrief"
const SERETH_CUT_DISPATCH := &"sereth_cut_dispatch"
const SERETH_CUT_DEBRIEF := &"sereth_cut_debrief"
const MARA_PORTRAIT := preload("res://assets/art/mara.webp")
const RASKA_PORTRAIT := preload("res://assets/art/raska.webp")
const SOVA_PORTRAIT := preload("res://assets/art/sova.webp")
const ILYRA_PORTRAIT := preload("res://assets/art/ilyra.webp")
const NERIS_PORTRAIT := preload("res://assets/art/neris.webp")
const SERETH_PORTRAIT := preload("res://assets/art/sereth.webp")
const MARA := "King Mara Halden"
const CAPTAIN := "Royal Captain"
const RASKA := "War Marshal Raska Vennor"
const LIEUTENANT := "Basin Lieutenant"
const LOWER_CAPTAIN := "Lower-Town Captain"
const MINER := "Mine Witness"
const SOVA := "First Listener Sova Cairn"
const GUARD := "Cairnspine Guard"
const SCRIBE := "Public Scribe"
const ORC_WITNESS := "Orc Witness"
const ELVEN_WITNESS := "Elven Witness"
const MARCH_WITNESS := "Marches Witness"
const CLERK := "Council Clerk"
const MILLER := "Mill Steward"
const BAKER := "Town Baker"
const JUDGE := "Marches Judge"
const ENVOY := "Allied Envoy"
const ILYRA := "Tide Speaker Ilyra Venn"
const PILOT := "Moonwash Pilot"
const SIGNALLER := "Fleet Signaller"
const PORT_CLERK := "Harbor Clerk"
const INLET_PILOT := "Fishing Inlet Pilot"

const NERIS := "Rootspeaker Neris Alder"
const GROVE_ENVOY := "Grove Envoy"
const FEEDER_KEEPER := "Town Feeder Keeper"
const SERETH := "High Executor Sereth Vale"
const IREN := "Iren"
const VILLAGE_CLERK := "Village Clerk"
const HOUSEHOLD_GUARD := "Household Guard"

const BEATS := {
	MARA_MINE_DISPATCH: {
		"title": "Orders for the Pass",
		"location": "Marches command post · Before the mine escort",
		"lines": [
			{"speaker": CAPTAIN, "text": "The riverbed's dry. Our scouts watched an Orc company turn toward the pass. If they reach it first, we'll have no room to move."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Put my seal on the Godbridle's case. I want the bridle through the pass and into the Marches."},
			{"speaker": CAPTAIN, "text": "I'll put the shields where the road narrows. The archers can cover them from the ridge."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Give the carrier room to run. We don't have to win the road. We have to get through it."},
		],
	},
	MARA_MINE_DEBRIEF: {
		"title": "The Same Night",
		"location": "Marches command post · After the mine escort",
		"lines": [
			{"speaker": CAPTAIN, "text": "The case came through under your seal. None of the miners came with us. Sova led them out through the tunnels. One went with Raska of her own accord."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Did anyone write down what she saw?"},
			{"speaker": CAPTAIN, "text": "We have a copy of her account. She says the new spring opened the same night the river went dry."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Put her dates in our report. And ask the granaries how long their stores will last if the river stays dry."},
		],
	},
	RASKA_MINE_DISPATCH: {
		"title": "Someone Who Saw It",
		"location": "Basin camp · Before the mine escort",
		"lines": [
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "The assembly sent us after a river. The miners were here when it stopped. Get me to the outlet so I can ask them what they saw."},
			{"speaker": LIEUTENANT, "text": "If we hold the narrow part of the road, the second platoon can cross the ridge and come down under cover."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Hold the road only as long as you need to. Keep clear of the Druids and let the workers through."},
			{"speaker": LIEUTENANT, "text": "And if Mara gets the Godbridle past us?"},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Let his carrier go. We came for someone willing to speak at the assembly."},
		],
	},
	RASKA_MINE_DEBRIEF: {
		"title": "Her Own Account",
		"location": "Basin rally point · After the witness escort",
		"lines": [
			{"speaker": MINER, "text": "I saw the others reach the Druids. You let them go, like you said you would."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "And if you've changed your mind, the path back to them is clear."},
			{"speaker": MINER, "text": "I haven't. I'll tell the assembly myself. I saw the spring come up. Sova's survey dates it to the night your river stopped."},
			{"speaker": LIEUTENANT, "text": "Mara's carrier cleared the pass with the Godbridle. Do you want us to follow?"},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "No. Get us two copies of the survey. And tell the assembly she'll speak first."},
		],
	},
	RASKA_WELL_ROAD_DISPATCH: {
		"title": "The Second Bucket",
		"location": "Lower well storehouse · Before the escort",
		"lines": [
			{"speaker": LIEUTENANT, "text": "The new cut sent all our traffic to the wells. A March company is coming for both carts. Their own supply failed."},
			{"speaker": LOWER_CAPTAIN, "text": "I'll lend you my company. There are families at the lower storehouse who aren't on the well roll. Some came from the Marches. Do I turn them away?"},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Open the storehouse. Give them water and seats. Send the upper cart when it's ready. The lower cart waits until the households are aboard."},
			{"speaker": LIEUTENANT, "text": "The salt road is quicker, but their horses can get a run at us there. They won't have that room in the wash. Its ramp is narrow, though."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Take whichever road you can cover. I need both carts through the Basin exit."},
		],
	},
	RASKA_WELL_ROAD_DEBRIEF: {
		"title": "Past the Riverbanks",
		"location": "Basin receiving yard · After the escort",
		"lines": [
			{"speaker": LIEUTENANT, "text": "Both carts reached the Basin. The households from the lower storehouse came in with the second one."},
			{"speaker": LOWER_CAPTAIN, "text": "I counted the last barrels onto that cart myself. I'll take my company back below the river towns. What will a river do for us there?"},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "It'll put water back in the river towns. It won't reach every place that needs it."},
			{"speaker": LOWER_CAPTAIN, "text": "Our pastures were on the old shore. So were the boats that brought our grain. A river won't bring those boats back."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "The assembly sent me for its river. I can promise you that much. Not the sea."},
		],
	},
	RASKA_SPANWATER_DISPATCH: {
		"title": "River, Not Sea",
		"location": "Spanwater causeway · Before the release",
		"lines": [
			{"speaker": LIEUTENANT, "text": "Two controls. The spillway sends water down the old riverbed. Open the sea gate and the old shore fills. The assembly town stands below that waterline."},
			{"speaker": LOWER_CAPTAIN, "text": "I counted the last barrels onto your cart. We can get you to the wheel today. But my towns sent me to bring back the shore, not just fill your river."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "I remember what I promised. The assembly sent me for the river. The sea gate stays shut."},
			{"speaker": LOWER_CAPTAIN, "text": "Then we'll see you to the wheel, as agreed. If you open the spillway alone, our companies go home."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Take the raised causeway and clear the wheel. I'll open the spillway. Hold it until the river reaches its mark, then get to the high bank. The low crossing won't stay open."},
		],
	},
	RASKA_SPANWATER_DEBRIEF: {
		"title": "Below the Mark",
		"location": "Spanwater high bank · After the release",
		"lines": [
			{"speaker": LIEUTENANT, "text": "The spillway held. Water reached the mark in the old riverbed. The sea gate stayed shut; the assembly town is safe from the flood."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Boats at the low landing. People on the feeder path, too. Keep our regulars on the high bank. Leave those lanes to them."},
			{"speaker": LIEUTENANT, "text": "The captain's companies raised their standards and left by the causeway when we opened the spillway. I asked her if we should expect them back. She said no."},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Put that in the report. Don't fill their places on the roster until someone actually comes to stand in them."},
			{"speaker": LIEUTENANT, "text": "What do I tell the lower towns when they ask where the water stops?"},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Tell them where it stops. They shouldn't have to come all this way to find out."},
		],
	},
	RASKA_SPANWATER_CODA: {
		"title": "What I Saw",
		"location": "Spanwater · Later that year",
		"lines": [
			{"speaker": SCRIBE, "text": "The case is closed. For the assembly's copy: what did you see change hands?"},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "I saw Mara hand the Godbridle to Sova. The Elven witness saw it too. Write that Sova took custody. That's what we came to witness."},
			{"speaker": SCRIBE, "text": "Shall I put it with the report on the water?"},
			{"speaker": RASKA, "portrait": RASKA_PORTRAIT, "text": "Separate page. One says who carries the bridle. The other says who got water. Don't let anyone read one as an answer to the other."},
		],
	},
	SOVA_MINE_DISPATCH: {
		"title": "The Workers First",
		"location": "Old mine tunnels · Before the evacuation",
		"lines": [
			{"speaker": GUARD, "text": "One group is waiting by the tunnel mouth. The second is at the bend. Do I send them both?"},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Let me check the outlet first. When I signal, send the first group. Keep the second at the bend until the path is clear again."},
			{"speaker": GUARD, "text": "Mara's escort is moving on the pass. Are we leaving the Godbridle to them?"},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Yes. My survey dates the spring to the night the river vanished. It can't tell us what the miners asked Orrun. First, let's get them somewhere safe."},
		],
	},
	SOVA_MINE_DEBRIEF: {
		"title": "Keep the Copy",
		"location": "Cairnspine refuge · After the evacuation",
		"lines": [
			{"speaker": GUARD, "text": "Both groups are through the tunnels. One miner waited at the outlet until the rest were safe. Then she went with Raska."},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "That was her choice?"},
			{"speaker": GUARD, "text": "She said so herself. Mara's carrier cleared the pass with the Godbridle. We have a copy of the account she gave Raska."},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Fold it into the survey. When we get home, ask the Keepers to bring out the old sealed record. I'm going to read it to the valleys."},
		],
	},
	SOVA_PUBLIC_RECORD_DISPATCH: {
		"title": "Let Them Walk Out",
		"location": "Valley assembly · Before the public reading",
		"lines": [
			{"speaker": GUARD, "text": "Armed groups are watching the open dais. The recessed lectern has cover, but its public exit is close to the approach."},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Bring the record and a public scribe to whichever lectern we choose. Put the guards outside the ring and keep the exit clear."},
			{"speaker": SCRIBE, "text": "Several Keepers are standing by that exit. Do we wait if they leave before you read the names?"},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Let them go. My predecessors put those names under seal. I'm reading all three passages whether the Keepers stay or not."},
		],
	},
	SOVA_PUBLIC_RECORD_DEBRIEF: {
		"title": "Copies at the Door",
		"location": "Valley assembly · After the public reading",
		"lines": [
			{"speaker": SCRIBE, "text": "I have all three passages: who gave the command to raise the Cairnspine, how the Elven coast drowned, and how the Red Basin lost its sea."},
			{"speaker": GUARD, "text": "Some of the Keepers left. Do you want them brought back to answer for what we heard?"},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "No. Move the guards away from the exit. If I ever ask those valleys for their help, they need to be able to say no."},
			{"speaker": SCRIBE, "text": "I made a copy for Ilyra. I can leave another at the door for anyone who wants it."},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Do that. Keep the record open here. Nobody should have to ask a Keeper before they can read it again."},
		],
	},
	SOVA_GODBRIDLE_HANDOVER: {
		"title": "In Sight of Witnesses",
		"location": "Spanwater · Year Four, after the breach",
		"lines": [
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "I won't ask Orrun to close the breach. Before another crown comes for the Godbridle, I want you to take custody of it."},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Break the seal so the witnesses can see what's inside. We don't need to say a word to it."},
			{"speaker": ELVEN_WITNESS, "text": "I see the bridle. I'll attest that it passed from your hands to his."},
			{"speaker": ORC_WITNESS, "text": "So will I. I'm here to witness a handover, not to sign away anyone's claim."},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Close the case. I'll take it into custody. When the valleys meet, this goes into the public record too."},
		],
	},
	SOVA_VAULT_RETURN_DISPATCH: {
		"title": "No New Command",
		"location": "Cairnspine assembly · Year Five, before the vault return",
		"lines": [
			{"speaker": GUARD, "text": "The shelf is the shorter climb. The side path bends back to the same forecourt. A rival reserve is gathering north of it."},
			{"speaker": SCRIBE, "text": "The valleys pledged their guards when we put the full record into the custody terms. The witnesses have their own way to the terrace."},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "I'll carry the Godbridle. Hold the approach to the vault, and leave the witness road open."},
			{"speaker": GUARD, "text": "If their reserve gets inside the closure ring, do we follow them in?"},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Give me room to step back. Clear the ring, and I'll try the door again. We're here to return the bridle. No one gives a new command."},
		],
	},
	SOVA_VAULT_RETURN_DEBRIEF: {
		"title": "Leave the Record Open",
		"location": "Cairnspine witness terrace · Year Five, after closure",
		"lines": [
			{"speaker": ORC_WITNESS, "text": "I watched Mara hand you that case at Spanwater. From the terrace I saw you carry it into the vault."},
			{"speaker": ELVEN_WITNESS, "text": "I saw the same, and I saw the door shut. I'll put my name to the return."},
			{"speaker": MARCH_WITNESS, "text": "And mine. What do I tell the towns still waiting for their water?"},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Orrun is still carrying out Mara's order. The Godbridle is back in the vault. We gave no new command."},
			{"speaker": SCRIBE, "text": "I'll leave a copy at the assembly. Who may read the vault record?"},
			{"speaker": SOVA, "portrait": SOVA_PORTRAIT, "text": "Leave it open to every valley. Keep our names in it, even when the people asking to read it have reason to blame us."},
		],
	},
	MARA_GRAIN_DISPATCH: {
		"title": "Grain on Credit",
		"location": "Marches council chamber · Before the crossing",
		"lines": [
			{"speaker": CAPTAIN, "text": "Two carts on credit after the second bad harvest. Rival levies are waiting to impound them. The crown that sent them wants an answer about the water."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Send the seed across the bridge to the mill yard. The bread grain goes by the lower ford to the town store."},
			{"speaker": CAPTAIN, "text": "The bridge is exposed. If we send both escorts out at once, there'll be no one left at the fork."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Hold a reserve there. If a cart can't get through, turn it back and get the other one home. We need the grain, not the bridge."},
		],
	},
	MARA_GRAIN_SEED_DEBRIEF: {
		"title": "Leave the Seed Sealed",
		"location": "Marches council chamber · After the crossing",
		"lines": [
			{"speaker": MILLER, "text": "The seed is in the mill yard. The growers can plant the south fields if I keep those sacks out of the mill."},
			{"speaker": CLERK, "text": "The bread cart never reached the town store. The bakers want to know what goes in tomorrow's dough."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Give the town ovens the flour we can spare. Leave the seed sealed."},
			{"speaker": CLERK, "text": "The allied crown will recall its troops and stop the grain unless we make good on water."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Bring the Godbridle in. Have the surveyors mark the dry headwater channels before we speak to Orrun."},
		],
	},
	MARA_GRAIN_BREAD_DEBRIEF: {
		"title": "One Week of Bread",
		"location": "Marches council chamber · After the crossing",
		"lines": [
			{"speaker": BAKER, "text": "The bread grain is in the town store. We can keep the ovens lit this week."},
			{"speaker": CLERK, "text": "The mill yard got no seed. The growers ask whether to sow what they have left or save it for food."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Have them count what they can still plant. Don't open the last sacks tonight."},
			{"speaker": CLERK, "text": "Our ally says there'll be no more grain and no troops if the channels stay dry."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Send for the Godbridle. I want a map of the headwaters on this table when we speak to Orrun."},
		],
	},
	MARA_GRAIN_BOTH_DEBRIEF: {
		"title": "Both Receipts",
		"location": "Marches council chamber · After the crossing",
		"lines": [
			{"speaker": MILLER, "text": "The seed cart is checked in at the mill yard. The growers are coming for their shares at first light."},
			{"speaker": BAKER, "text": "And the bread grain made the town store. I'll have the ovens lit before they get there."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Two receipts at last. How long can we feed the towns before another shipment is due?"},
			{"speaker": CLERK, "text": "Not long enough. Our ally won't send another cart and will call its troops home unless the water comes back."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Keep the receipts. Bring the Godbridle and the headwater map. We still need to speak to Orrun."},
		],
	},
	MARA_WATER_REQUEST: {
		"title": "The Dry Channels",
		"location": "Marches council chamber · After the Grain debrief",
		"lines": [
			{"speaker": CLERK, "text": "The envoy is still downstairs. If he goes home without an answer, his crown will call its troops back and send us no more grain."},
			{"speaker": JUDGE, "text": "I see the dry channels on your map. Whose water will fill them?"},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "I'll name the channels, not a river. And I'll tell him what to leave alone. Bring the case here."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Orrun, return water to the dry headwater channels of the Marches. Take none from the towns or fields of our neighbors."},
		],
	},
	MARA_HIGH_QUAY_DISPATCH: {
		"title": "Orders for the High Quay",
		"location": "Marches command post · Before the Moonwash withdrawal",
		"lines": [
			{"speaker": CAPTAIN, "text": "A pilot at Moonwash saw the current running inland. Her letter doesn't say where it turned. No one here has seen it."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Take both platoons to Moonwash. Warn the pilots before any more boats go out. Bring me an account from someone who saw where the current changed."},
			{"speaker": CAPTAIN, "text": "If we need to pull back, the pilots mark the upper stairs with flags. The town will need the lower stair for its own people."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Use the upper stairs, and cover each other's way up. Leave the boats to Ilyra. You're there to warn the harbor, not take it."},
		],
	},
	MARA_HIGH_QUAY_DEBRIEF: {
		"title": "Two Reports",
		"location": "Marches council chamber · After the withdrawal",
		"lines": [
			{"speaker": CAPTAIN, "text": "Both platoons are out. I saw walls rise between the ships. Some are still stranded on stone, and Ilyra's pilots were hauling crews off them when we left."},
			{"speaker": CLERK, "text": "Here's the other report. Water reached some of the Marches. There are farms on your list that haven't had a drop."},
			{"speaker": ENVOY, "text": "Then speak to him again. At least get water to the farms you promised it to."},
			{"speaker": MARA, "portrait": MARA_PORTRAIT, "text": "Leave your report beside his. Close the case and leave my seal on it. There won't be a second order."},
		],
	},
	ILYRA_MOONWASH_DISPATCH: {
		"title": "Hulls on Stone",
		"location": "Moonwash moorings · Before the rescue",
		"lines": [
			{"speaker": PILOT, "text": "Stone's rising under the moorings. The hull won't come free. There are people cut off at both ends."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "That corner under the hull is where I grew up. Rig a line at either end and bring them across to our receiving deck."},
			{"speaker": SIGNALLER, "text": "One of the ports is signalling its pledged ships to leave. They want us to go after the Godbridle."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "Signal back that we're staying. Take the forward or aft line, whichever you can get to. Bring stores across if you can, but don't make anyone wait for a bundle."},
		],
	},
	ILYRA_MOONWASH_CARGO_DEBRIEF: {
		"title": "Stores Aboard",
		"location": "Moonwash receiving deck · After the rescue",
		"lines": [
			{"speaker": PILOT, "text": "Both crews are aboard. We got some stores across too. Enough to provision a few survey boats ourselves."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "Keep those stores for the survey. Ask the village pilots to come anyway. They know which inlets are still open."},
			{"speaker": PORT_CLERK, "text": "A scribe sent a copy of Sova's public account. He read the record of the Druid command that drowned the old coast."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "Lay it beside my old chart. I can mark where the streets were. Have the pilots mark where their boats land now."},
		],
	},
	ILYRA_MOONWASH_CREWS_DEBRIEF: {
		"title": "Stores on Loan",
		"location": "Moonwash receiving deck · After the rescue",
		"lines": [
			{"speaker": PILOT, "text": "Both crews are aboard. The cargo stayed with the hulls. We can get the survey boats out if the fishing villages lend us stores."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "Ask them what they can spare. Put every sack we borrow in the log, and ask their pilots to take us along the shore."},
			{"speaker": PORT_CLERK, "text": "Sova read the sealed record in public. This is a copy. It names the old Druid command that drowned the coast."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "Bring it when the pilots come in. I know where my street was. I want the chart to show where their villages fish and land now."},
		],
	},
	ILYRA_COAST_SURVEY_DISPATCH: {
		"title": "Two Shorelines",
		"location": "Moonwash Survey Shore · Before the soundings",
		"lines": [
			{"speaker": PORT_CLERK, "text": "The ports want a chart of the old coast for their claim. One sent armed crews ashore to take the chart straight to its own delegation."},
			{"speaker": INLET_PILOT, "text": "Raise those streets and my skiff may sit on stone. We'll show you our inlet if our soundings go on the same chart as yours."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "They will. I'll take a reading at the ancestral stone and one at the fishing inlet. Neither goes to the cutter without the other."},
			{"speaker": SIGNALLER, "text": "The cutter skirts the shoal and stops twice. The beach stop comes first, but the landing crews can reach it. The headland relay takes the inland ramp and gives us better cover."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "Hold whichever relay gives us a clear view of the cutter at its stop. Keep the signal up until they acknowledge both readings. If the cutter goes out of sight, keep the readings and try its next pass."},
		],
	},
	ILYRA_COAST_SURVEY_BEACH_DEBRIEF: {
		"title": "The Chart from the Beach",
		"location": "Moonwash survey cutter · After the beach signal",
		"lines": [
			{"speaker": SIGNALLER, "text": "The cutter acknowledged both readings from the beach. We held the signal long enough to send the stone and the inlet together."},
			{"speaker": PORT_CLERK, "text": "Which marks go in the copy for the ports? They only asked for the drowned coast."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "Both shorelines. Put the fishing harbor beside my old street. Give the villages the same chart. No one gets a copy with their neighbors rubbed out."},
			{"speaker": INLET_PILOT, "text": "I'll bring it back to the people who lent us their soundings. If you need boats in the shallows again, send for us."},
		],
	},
	ILYRA_COAST_SURVEY_HEADLAND_DEBRIEF: {
		"title": "The Chart from the Headland",
		"location": "Moonwash survey cutter · After the headland signal",
		"lines": [
			{"speaker": SIGNALLER, "text": "The cutter came clear of the headland and acknowledged both readings from the high relay. We sent the stone and the inlet together."},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "At the stone I could put my finger on my old street. From up there I could see where the fishing boats come home now. Draw both shorelines."},
			{"speaker": PORT_CLERK, "text": "One copy for the ports and one for the villages?"},
			{"speaker": ILYRA, "portrait": ILYRA_PORTRAIT, "text": "The same chart for all of them. Let the ports argue their claim with the inlet still on the page."},
			{"speaker": INLET_PILOT, "text": "I'll carry ours home. If you need boats in the shallows again, send for us."},
		],
	},
	NERIS_FAILING_GROVE_DISPATCH: {
		"title": "What We Planted Here",
		"location": "Isolated grove · Before the transplant",
		"lines": [
			{"speaker": NERIS, "portrait": NERIS_PORTRAIT, "text": "I thought I could bring the Deepwood to your roots. The river's new cut has left you dry."},
			{"speaker": GROVE_ENVOY, "text": "Your crossing would run under the wells of the town that gave us this ground. The grove said no. We asked you here to help move a tree."},
			{"speaker": FEEDER_KEEPER, "text": "The nursery has watered ground for the first one. Help us keep the old feeder open, and we'll keep that plot for you. The well is still the town's."},
			{"speaker": NERIS, "portrait": NERIS_PORTRAIT, "text": "No crossing. Show me the loading yard. I'll call the volunteers once we're there."},
			{"speaker": GROVE_ENVOY, "text": "Keep watch on the sunken track while we load. Take the raised road with the sled. It's the only way wide enough."},
		],
	},
	NERIS_FAILING_GROVE_DEBRIEF: {
		"title": "Room for the First Tree",
		"location": "Town nursery · After the transplant",
		"lines": [
			{"speaker": GROVE_ENVOY, "text": "The first tree is upright. Reach down past the cloth. The soil is wet all the way to the root ball."},
			{"speaker": FEEDER_KEEPER, "text": "I can water this plot. I can't fit the whole grove here today. The feeder needs hands before I can spare any more ground."},
			{"speaker": NERIS, "portrait": NERIS_PORTRAIT, "text": "I'll send a crew to the feeder. Tell me where they should meet you."},
			{"speaker": GROVE_ENVOY, "text": "We'll go back for the other trees when there's room. Their ground is still dry. You mean to keep asking for the Godbridle?"},
			{"speaker": NERIS, "portrait": NERIS_PORTRAIT, "text": "I'll still ask to hold it. The other groves may not have a town willing to lend them ground. But your answer about the crossing stands."},
		],
	},
	NERIS_SPANWATER_FEEDER_DISPATCH: {
		"title": "Water at the Town Gauge",
		"location": "Spanwater feeder path · Before the release",
		"lines": [
			{"speaker": FEEDER_KEEPER, "text": "The first tree is still on well water. Raska's opening the spillway, not the sea gate. A full river won't help that tree if the feeder fills with silt."},
			{"speaker": GROVE_ENVOY, "text": "The crew has the guide boards. The inlet rack is already clogged, and March troops have been seen on the maintenance path."},
			{"speaker": NERIS, "portrait": NERIS_PORTRAIT, "text": "I'll clear the rack. Hold a platoon at the work screen so the crew can fit the boards. If the first rush brings more debris, call me back to the rack."},
			{"speaker": FEEDER_KEEPER, "text": "Follow the raised path when the ford goes under. The gauge at the town end tells us whether water actually made it through."},
		],
	},
	NERIS_SPANWATER_FEEDER_DEBRIEF: {
		"title": "Take the Gauge",
		"location": "Town feeder gauge · After the crest",
		"lines": [
			{"speaker": GROVE_ENVOY, "text": "The water's at the town mark and holding. The boards stayed in place through the crest. Here's your gauge book."},
			{"speaker": FEEDER_KEEPER, "text": "I'll take the morning reading. The wells stay in town hands. The nursery plot stays yours, as agreed."},
			{"speaker": NERIS, "portrait": NERIS_PORTRAIT, "text": "Have someone show our volunteers how to read the mark. Put us on the rack patrol after storms. That tree will need water long after our platoons leave."},
			{"speaker": GROVE_ENVOY, "text": "I'll take the first turn. It used to take me all morning to carry enough water for one tree."},
		],
	},
	SERETH_CUT_DISPATCH: {
		"title": "Before Anyone Writes It Down",
		"location": "Still Kingdom village · Year Three, before the defense",
		"lines": [
			{"speaker": VILLAGE_CLERK, "text": "The bank fell away beside the old graves. It left a bundle of records below the stair. Iren asked to tell you what she heard. She's waiting above the cut."},
			{"speaker": HOUSEHOLD_GUARD, "text": "A March party is coming for the bundle. One guard can hold the stair while the other watches the road."},
			{"speaker": SERETH, "portrait": SERETH_PORTRAIT, "text": "Hold the stair. If they get the bundle first, stop the carrier before they reach the east exit. Bring the papers back to the record room."},
			{"speaker": VILLAGE_CLERK, "text": "I'll keep the account book open at my table. Come back and tell me what Iren says, even if the papers aren't here yet."},
			{"speaker": SERETH, "portrait": SERETH_PORTRAIT, "text": "I'll ask her what she wants on the page. Let her finish before we ask her to put her name to it."},
		],
	},
	SERETH_CUT_DEBRIEF: {
		"title": "In Her Own Words",
		"location": "Village record room · Year Three, after the defense",
		"lines": [
			{"speaker": IREN, "text": "I heard my name. I recognized the voice. I'll sign that much. Don't put anything else down for me."},
			{"speaker": VILLAGE_CLERK, "text": "That's what's in the account, under your name. The recovered bundle has its own entry in the register."},
			{"speaker": SERETH, "portrait": SERETH_PORTRAIT, "text": "Seal the bundle for cataloging. Don't send the court a list of names to call back. Hearing a name doesn't tell us who wants to return."},
			{"speaker": VILLAGE_CLERK, "text": "The court's courier is at the door. They want you to secure the Godbridle before anyone gives another command."},
			{"speaker": SERETH, "portrait": SERETH_PORTRAIT, "text": "I'll go. If you come across a letter for me, put it in the register with everything else. It can wait."},
		],
	},
}


## Resolve only validated successful Grain results. No default or progress side effects.
static func grain_debrief_id(result: StringName) -> StringName:
	match result:
		Grain.SEED_ONLY:
			return MARA_GRAIN_SEED_DEBRIEF
		Grain.BREAD_ONLY:
			return MARA_GRAIN_BREAD_DEBRIEF
		Grain.BOTH:
			return MARA_GRAIN_BOTH_DEBRIEF
	return &""


## The successful rescue outcome affects stores, not whether the next survey happens.
static func moonwash_debrief_id(result: StringName) -> StringName:
	match result:
		Moonwash.CARGO_RECOVERED:
			return ILYRA_MOONWASH_CARGO_DEBRIEF
		Moonwash.CREWS_ONLY:
			return ILYRA_MOONWASH_CREWS_DEBRIEF
	return &""


## Relay choice changes the report, not the chart or the next mission.
static func survey_debrief_id(phase: Survey.Phase, signal_site: Survey.SignalSite) -> StringName:
	if phase != Survey.Phase.SUCCEEDED:
		return &""
	match signal_site:
		Survey.SignalSite.BEACH:
			return ILYRA_COAST_SURVEY_BEACH_DEBRIEF
		Survey.SignalSite.HEADLAND:
			return ILYRA_COAST_SURVEY_HEADLAND_DEBRIEF
	return &""


static func get_beat(id: StringName) -> Dictionary:
	var beat: Dictionary = BEATS.get(id, {})
	if beat.is_empty():
		# Missions on the generic mission view author their beats with their data.
		var generic: GDScript = load("res://game/mission/mission_dialogues.gd")
		var view: GDScript = load("res://game/mission/mission_view.gd")
		return generic.get_beat(id, view.last_flags)
	return beat.duplicate(true)
