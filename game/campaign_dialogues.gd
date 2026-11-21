extends RefCounted
## Authored conversations. A route may replay a beat without mutating its source.

const MARA_MINE_DISPATCH := &"mara_mine_dispatch"
const MARA_MINE_DEBRIEF := &"mara_mine_debrief"
const MARA_PORTRAIT := preload("res://assets/art/mara.webp")
const MARA := "King Mara Halden"
const CAPTAIN := "Royal Captain"

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
}


static func get_beat(id: StringName) -> Dictionary:
	var beat: Dictionary = BEATS.get(id, {})
	return beat.duplicate(true)
