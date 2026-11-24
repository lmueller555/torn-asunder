extends "res://game/battlefield/mara_mine_escort.gd"
## March, command, and combat are inherited. Only the rescue controls victory;
## the campaign owner reacts to the inherited terminal signal.

enum Rescue { RALLY, ESCORT, SUCCEEDED, FAILED }
enum Miner { WAITING, FOLLOWING, SAFE, LOST }

const CharacterArt := preload("res://game/battlefield/mara_campaign_character_art.gd")
const Minimap := preload("res://game/battlefield/battlefield_minimap.gd")
const RALLY_PATH := ^"Markers/Routes/TunnelEntrance"
const SAFETY_PATH := ^"Markers/Objectives/MinerEvacuation"
const RESCUE_ROUTE := [
	^"Markers/Routes/TunnelMidpoint",
	^"Markers/Routes/TunnelExit",
	^"Markers/Routes/EvacuationTurn",
	^"Markers/Routes/EvacuationTrail",
	SAFETY_PATH,
]
const RALLY_RADIUS := 3.1
const COVER_RADIUS := 13.0
const RAID_TRIGGER_RADIUS := 19.0
const MINER_SPEED := 3.65
const MINER_COUNT := 3
const MIN_SAFE := 2
const MINER_TOUGHNESS := 2
const DRYAD_DAMAGE := 46.0

class CrewMember:
	var model: Node3D
	var position: Vector2
	var condition := Miner.WAITING
	var blows_left := MINER_TOUGHNESS
	var next_leg := 0

var rescue_phase := Rescue.RALLY
var _crew: Array[CrewMember] = []
var _escape_route := PackedVector2Array()
var _dryad_released := false


func _ready() -> void:
	super._ready()
	CharacterArt.attach(self)


func _bind_objective() -> void:
	_pickup = battlefield_marker(RALLY_PATH)
	_exit = battlefield_marker(SAFETY_PATH)
	for path in RESCUE_ROUTE:
		_escape_route.append(_marker_position(battlefield_marker(path)))
	_pickup_beacon = _beacon(_pickup, RALLY_RADIUS, WARM_LIGHT, "HUMAN MINERS")
	_exit_beacon = _beacon(_exit, 2.8, EXIT_LIGHT, "SAFE HOLLOW")
	for index in range(MINER_COUNT):
		var worker := CrewMember.new()
		worker.model = _make_miner(index)
		_crew.append(worker)
	_reset_objective()


func _reset_objective() -> void:
	rescue_phase = Rescue.RALLY
	_dryad_released = false
	for index in range(_crew.size()):
		var miner := _crew[index]
		miner.condition = Miner.WAITING
		miner.blows_left = MINER_TOUGHNESS
		miner.next_leg = 0
		miner.position = _marker_position(_pickup) + _rally_offset(index)
		miner.model.position = _ground(miner.position)
		miner.model.rotation = Vector3(0, PI, 0)
		miner.model.show()


func _rally_offset(index: int) -> Vector2:
	# The crew starts bunched at the portal with enough space to move and target each miner.
	return [Vector2(0, 0), Vector2(-0.7, 1.6), Vector2(0.7, 3.2)][index]


## No result for unfinished/failing attempts. A Retry creates a new owner
## with no recorded kill. The reserved Dryad is the only combat enemy here.
func confirmed_enemy_defeats_on_victory() -> Variant:
	if scene_file_path != GREYHOLLOW_STARTING_SCENE or rescue_phase != Rescue.SUCCEEDED:
		return null
	return int(encounter != null and encounter.enemy_defeated_in_combat)


func _reset_encounter() -> void:
	super._reset_encounter()
	if encounter:
		encounter.enemy_phase = Encounter.EnemyPhase.AT_RESERVE
		encounter.hold_story_lane = true
		encounter.enemy_damage = DRYAD_DAMAGE
		encounter.civilian_positions = _miner_targets
		encounter.civilian_hit = _strike_miner
		encounter.civilian_aggro_radius = 34.0
		_refresh_combat_view()


func _after_battle_step(delta: float) -> void:
	# Only release the attack when it can be seen/interrupted. A player can
	# read the opening instructions or give formation orders without losing miners offscreen.
	if not _dryad_released and encounter and encounter.enemy.is_alive():
		var near_yard := battle.hero_position.distance_to(encounter.enemy_position) <= RAID_TRIGGER_RADIUS
		var engaged := battle.formations[0].order == Battle.Order.ATTACK \
			or battle.formations[1].order == Battle.Order.ATTACK
		if near_yard or engaged or rescue_phase == Rescue.ESCORT:
			_dryad_released = true
			encounter.enemy_phase = Encounter.EnemyPhase.PURSUING
	super._after_battle_step(delta)


func _miner_targets() -> PackedVector2Array:
	var targets := PackedVector2Array()
	for miner in _crew:
		# Keep stable indices so a committed swing cannot jump to a different miner.
		targets.append(miner.position if miner.condition in [Miner.WAITING, Miner.FOLLOWING] else Vector2.INF)
	return targets


func _strike_miner(index: int) -> bool:
	if _crew[index].condition not in [Miner.WAITING, Miner.FOLLOWING]:
		return false
	var miner := _crew[index]
	miner.blows_left -= 1
	if miner.blows_left <= 0:
		miner.condition = Miner.LOST
		miner.model.hide()
	return true


func _advance_objective(feet: Vector3, delta: float) -> void:
	if _hero_incapacitated or MINER_COUNT - _count(Miner.LOST) < MIN_SAFE:
		rescue_phase = Rescue.FAILED
		return
	if rescue_phase == Rescue.RALLY:
		if _interact_requested and not command_view and feet.distance_to(_pickup.global_position) <= RALLY_RADIUS:
			rescue_phase = Rescue.ESCORT
			for miner in _crew:
				if miner.condition == Miner.WAITING:
					miner.condition = Miner.FOLLOWING
	_interact_requested = false
	if rescue_phase != Rescue.ESCORT:
		return
	for index in range(_crew.size()):
		_advance_miner(index, delta)
	var saved := _count(Miner.SAFE)
	if saved >= MIN_SAFE and saved + _count(Miner.LOST) == MINER_COUNT:
		rescue_phase = Rescue.SUCCEEDED


func _advance_miner(index: int, delta: float) -> void:
	var miner := _crew[index]
	if miner.condition != Miner.FOLLOWING or not _has_escort(miner):
		return
	var is_last_leg := miner.next_leg == _escape_route.size() - 1
	var target := _escape_route[miner.next_leg]
	if not is_last_leg:
		# Stagger the line through the surveyed portal rather than stacking the crew.
		target += Vector2(_rally_offset(index).x, -float(index) * 0.7)
	else:
		target += Vector2(0.0, (index - 1) * 1.15)
	var next := miner.position.move_toward(target, MINER_SPEED * delta)
	if not _terrain.can_move(miner.position, next, false):
		return
	var heading := (next - miner.position).normalized()
	if not heading.is_zero_approx():
		miner.model.rotation.y = atan2(-heading.x, -heading.y)
	miner.position = next
	miner.model.position = _ground(next)
	if next != target:
		return
	if is_last_leg:
		miner.condition = Miner.SAFE
	else:
		miner.next_leg += 1


func _has_escort(miner: CrewMember) -> bool:
	return miner.position.distance_to(battle.hero_position) <= COVER_RADIUS \
		and _terrain.clear_melee_contact(miner.position, battle.hero_position)


func _count(condition: Miner) -> int:
	var total := 0
	for miner in _crew:
		if miner.condition == condition:
			total += 1
	return total


func _finished() -> bool:
	return rescue_phase in [Rescue.SUCCEEDED, Rescue.FAILED]


func _objective_won() -> bool:
	return rescue_phase == Rescue.SUCCEEDED


func _enemy_title() -> String:
	return "Dryad raider"


func _enemy_color() -> Color:
	return Color("#63845a")


func _enemy_reserve_readout() -> String:
	return "Dryad raider at the mine yard"


func alternate_minimap_objective() -> Dictionary:
	var landmarks := []
	if rescue_phase == Rescue.RALLY:
		landmarks.append([&"Human miners", RALLY_PATH, Minimap.ObjectiveKind.PICKUP])
	elif rescue_phase == Rescue.ESCORT:
		landmarks.append([&"Safe hollow", SAFETY_PATH, Minimap.ObjectiveKind.EXIT])
	return {"place": "GREYHOLLOW", "enemy": &"Dryad raider", "landmarks": landmarks}


func _refresh_objective_view(feet: Vector3) -> void:
	_pickup_beacon.visible = rescue_phase == Rescue.RALLY
	_exit_beacon.visible = rescue_phase == Rescue.ESCORT
	match rescue_phase:
		Rescue.RALLY:
			var distance := feet.distance_to(_pickup.global_position)
			_goal_label.text = "Reach the miners at the tunnel  ·  %d m" % ceili(distance)
			if distance > RALLY_RADIUS:
				_instructions_label.text = "Dryads are attacking the mine. Get the crew out.\nUse your platoons to shield the tunnel approach."
			elif command_view:
				_instructions_label.text = "Release L2 / Shift to rally the miners as Mara."
			else:
				_instructions_label.text = "Cross / Space: Rally the miners."
		Rescue.ESCORT:
			_goal_label.text = "Miners safe: %d/%d  ·  Lost: %d" % [_count(Miner.SAFE), MINER_COUNT, _count(Miner.LOST)]
			_instructions_label.text = "Take the crew through the tunnel to the safe hollow.\nStay close so they keep moving. At least two must reach safety."
		Rescue.SUCCEEDED:
			_goal_label.text = "Rescue complete"
			_instructions_label.text = "%d miners reached the safe hollow." % _count(Miner.SAFE)
		Rescue.FAILED:
			_goal_label.text = "Rescue failed"
			_instructions_label.text = "Mara fell. Restart to try again." if _hero_incapacitated \
				else "Too many miners were lost. Restart to try again."


func _make_miner(index: int) -> Node3D:
	# The same clearly provisional worker shape already used by the Mine evacuation.
	var worker := Node3D.new()
	worker.name = "HumanMiner%d" % (index + 1)
	add_child(worker)
	var coat := _material(Color("#f3c681"))
	_mesh(worker, _box(Vector3(0.43, 0.81, 0.35)), coat, Vector3.UP * 0.74)
	for x in [-0.11, 0.11]:
		_mesh(worker, _box(Vector3(0.14, 0.42, 0.26)), coat, Vector3(x, 0.24, 0.0))
	_mesh(worker, _box(Vector3(0.28, 0.29, 0.26)), _material(Color("#dcaa84")), Vector3.UP * 1.27)
	return worker
