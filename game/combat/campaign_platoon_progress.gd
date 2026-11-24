extends RefCounted
## Derive a provisional lead-platoon progression plan from confirmed clears.
## Neither a replay result nor an arbitrary visit can grant experience.

const Missions := preload("res://game/campaign_missions.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const BP := preload("res://game/combat/battle_points.gd")

const XP_PER_FIRST_CLEAR := 100


class Frame:
	var campaign_id: String
	var confirmed_chapters: int
	var total_xp: int
	var lead_level: int
	var xp_in_level: int
	var next_level_xp: int
	var next_mission_bp: int
	var next_mission_capacity: int


static func inspect(campaign_id: String, completed_ids: PackedStringArray, combat_bonuses := {}) -> Frame:
	var chapters := Missions.missions_for_campaign(campaign_id)
	if chapters.is_empty():
		return null
	var count := 0
	var combat_xp := 0
	for chapter in chapters:
		if not completed_ids.has(chapter.id):
			break
		count += 1
		var bonus: Variant = combat_bonuses.get(chapter.id, 0)
		if bonus is int and bonus > 0:
			combat_xp += bonus
	var lead := Unit.new()
	var xp := count * XP_PER_FIRST_CLEAR + combat_xp
	lead.award_experience(xp)
	var pool := BP.new(lead.level)
	var frame := Frame.new()
	frame.campaign_id = campaign_id
	frame.confirmed_chapters = count
	frame.total_xp = xp
	frame.lead_level = lead.level
	frame.xp_in_level = lead.experience
	frame.next_level_xp = lead.experience_for_next_level()
	frame.next_mission_bp = pool.balance
	frame.next_mission_capacity = pool.capacity
	return frame
