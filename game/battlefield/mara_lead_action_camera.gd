extends RefCounted
## Campaign presentation only. Mara is a focus subject, not an orderable formation.

const Mission := preload("res://game/battlefield/mara_mine_escort.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const ACTION_ARM := 4.8
const BLEND_RATE := 3.0
const LABEL := "MARA ACTION  /  LIVE"

var focused := false
var active := false
var _blend := 0.0


func clear() -> void:
	focused = false
	active = false
	_blend = 0.0


func frame(mission: Mission, delta: float) -> void:
	if mission._finished():
		clear()
	var camera: Camera3D = mission._hero_camera
	if not focused or mission.command_view or not camera.is_current() or not _in_contact(mission):
		active = false
		_blend = 0.0
		return
	# The parent has already calculated the ordinary orbit and its terrain clip.
	# Tighten along that same arm, never push past a shorter clipped normal pose.
	var pivot := mission._ground(mission.battle.hero_position, 1.15)
	var arm := camera.position - pivot
	var length := arm.length()
	_blend = move_toward(_blend, 1.0, BLEND_RATE * delta)
	if length > ACTION_ARM:
		var desired := pivot + arm * (lerpf(length, ACTION_ARM, _blend) / length)
		camera.position = mission._terrain.camera_position(pivot, desired)
		camera.look_at(mission.to_global(pivot + Vector3(0, 0, -2).rotated(Vector3.UP, mission._hero_yaw)))
	active = true
	mission._mode_label.text = LABEL


func _in_contact(mission: Mission) -> bool:
	var fight := mission.encounter
	return fight != null and fight.hero.is_alive() and fight.enemy.is_alive() \
		and fight.enemy_phase in [Encounter.EnemyPhase.PURSUING, Encounter.EnemyPhase.WINDUP, Encounter.EnemyPhase.RECOVERY] \
		and mission.battle.hero_position.distance_squared_to(fight.enemy_position) <= Encounter.CONTACT_RANGE ** 2 \
		and mission._terrain.clear_melee_contact(mission.battle.hero_position, fight.enemy_position)
