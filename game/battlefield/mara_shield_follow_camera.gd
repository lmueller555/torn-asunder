extends RefCounted
## Presentation-only follow for one actual engagement in Mara's campaign Mine.
## The command camera stays orthographic; no selection, orders or cursor values change.

const Policy := preload("res://game/battlefield/engagement_camera_policy.gd")
const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Infantry := preload("res://game/battlefield/mara_infantry_attack.gd")

const ROSTER: Array[StringName] = [&"shield_infantry", &"archers"]
const MAX_SHIFT := 14.0
const FOLLOW_SPEED := 24.0
const FOLLOW_LABEL := "SHIELD INFANTRY FOLLOW  /  LIVE"

var active := false
var _policy := Policy.new(&"mara")
var _shift := Vector3.ZERO


func _init() -> void:
	_policy.set_active_platoons(ROSTER)


func frame(mission: Mission, minimap_aiming: bool, delta: float) -> void:
	var camera: Camera3D = mission._command_camera
	# Called by the campaign HUD after the parent mission's normal camera
	# update. Apply a presentation offset to that frame's ordinary pose only.
	if (not mission.command_view or not mission._sector or mission._sector.overview
			or mission._finished() or minimap_aiming or mission._mouse_cursor_active
			or not mission._movement_input().is_zero_approx()
			or not camera.is_current()):
		restore(mission)
		return

	var selected := mission.selected_index
	var group := mission.battle.formations[selected]
	_policy.select(ROSTER[selected])
	_policy.observe_engaged(ROSTER[Infantry.INFANTRY_INDEX],
		selected == Infantry.INFANTRY_INDEX and _in_contact(mission, group))
	if _policy.mode() != Policy.Mode.PLATOON_FOLLOW:
		restore(mission)
		return

	var toward: Vector2 = (group.position - mission._sector.view_center()).limit_length(MAX_SHIFT)
	var next := _shift.move_toward(Vector3(toward.x, 0, toward.y), FOLLOW_SPEED * delta)
	camera.position += next
	var window := mission.get_viewport().get_visible_rect()
	var safe := window.grow(-0.06 * minf(window.size.x, window.size.y))
	var cursor_screen := camera.unproject_position(mission.to_global(mission._ground(mission.cursor)))
	var infantry_screen := camera.unproject_position(mission.to_global(mission._ground(group.position)))
	if not safe.has_point(cursor_screen) or not safe.has_point(infantry_screen):
		camera.position -= next
		restore(mission)
		return

	_shift = next
	active = true
	mission._mode_label.text = FOLLOW_LABEL


## Drop the presentation offset before yielding to an input or another mode.
func restore(mission: Mission) -> void:
	if active:
		# Derive the exact normal projection from the untouched tactical sector,
		# including if the player acts before the next parent physics update.
		mission._update_cameras()
	_shift = Vector3.ZERO
	active = false
	if mission._mode_label.text == FOLLOW_LABEL:
		mission._mode_label.text = "TACTICAL SECTOR  /  LIVE"


func _in_contact(mission: Mission, group: Battle.Formation) -> bool:
	var fight := mission.encounter
	return fight != null and fight.enemy.is_alive() and fight.infantry_attack.attacker.is_alive() \
		and group.order == Battle.Order.ATTACK \
		and fight.enemy_phase not in [Encounter.EnemyPhase.AT_RESERVE, Encounter.EnemyPhase.INTERCEPTING] \
		and group.position.distance_squared_to(fight.enemy_position) <= Infantry.REACH * Infantry.REACH \
		and mission._terrain.clear_melee_contact(group.position, fight.enemy_position)
