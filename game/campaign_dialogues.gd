extends RefCounted
## Authored conversations. A route may replay a beat without mutating its source.

const Grain := preload("res://game/battlefield/mara_grain_crossing.gd")

const MARA_MINE_DISPATCH := &"mara_mine_dispatch"
const MARA_MINE_DEBRIEF := &"mara_mine_debrief"
const RASKA_MINE_DISPATCH := &"raska_mine_dispatch"
const RASKA_MINE_DEBRIEF := &"raska_mine_debrief"
const SOVA_MINE_DISPATCH := &"sova_mine_dispatch"
const SOVA_MINE_DEBRIEF := &"sova_mine_debrief"
const MARA_GRAIN_DISPATCH := &"mara_grain_dispatch"
const MARA_GRAIN_SEED_DEBRIEF := &"mara_grain_debrief_seed_only"
const MARA_GRAIN_BREAD_DEBRIEF := &"mara_grain_debrief_bread_only"
const MARA_GRAIN_BOTH_DEBRIEF := &"mara_grain_debrief_both"
const MARA_PORTRAIT := preload("res://assets/art/mara.webp")
const RASKA_PORTRAIT := preload("res://assets/art/raska.webp")
const SOVA_PORTRAIT := preload("res://assets/art/sova.webp")
const MARA := "King Mara Halden"
const CAPTAIN := "Royal Captain"
const RASKA := "War Marshal Raska Vennor"
const LIEUTENANT := "Basin Lieutenant"
const MINER := "Mine Witness"
const SOVA := "First Listener Sova Cairn"
const GUARD := "Cairnspine Guard"
const CLERK := "Council Clerk"
const MILLER := "Mill Steward"
const BAKER := "Town Baker"

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


static func get_beat(id: StringName) -> Dictionary:
	var beat: Dictionary = BEATS.get(id, {})
	if beat.is_empty():
		# Missions on the generic mission view author their beats with their data.
		var generic: GDScript = load("res://game/mission/mission_dialogues.gd")
		var view: GDScript = load("res://game/mission/mission_view.gd")
		return generic.get_beat(id, view.last_flags)
	return beat.duplicate(true)
