extends SceneTree

const Aggro := preload("res://game/combat/enemy_aggro.gd")
const Encounter := preload("res://game/battlefield/mara_mine_encounter.gd")
const Levy := preload("res://game/battlefield/moonwash_levy_patrol.gd")
const Patrol := preload("res://game/battlefield/patrol_detection_policy.gd")
const Writ := preload("res://game/battlefield/sereth_pass_writ_playtest.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const Terrain := preload("res://game/battlefield/command_terrain.gd")
const DT := 1.0 / 60.0
var _failures := 0
var _checks := 0
var _visible := true
var _melee := false


class TestQuayTerrain extends Terrain:
	var visible := true

	func ground_height(_at: Vector2) -> float:
		return 0.0

	func clear_ranged_lane(_start: Vector3, _end: Vector3) -> bool:
		return visible

	func can_move(_from: Vector2, _to: Vector2, _formation: bool) -> bool:
		return true


class TestWrit extends Writ:
	var clear := true

	func _clear_sight(_from: Vector3, _to: Vector3) -> bool:
		return clear


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Aggro.RADIUS_METRES == 50.0, "The shared value is canonical and inclusive at 50 m.")
	_mine()
	_quay()
	_writ()
	_check(Encounter.CONTACT_RANGE == 1.75 and Levy.LEASH == 18.0 and Writ.PATROL_RANGE == 33.0,
		"The attack contact, quay pursuit leash and Writ's objective pressure stay authored.")
	print("Authored enemy aggro: %d/%d checks passed." % [_checks - _failures, _checks])
	quit(0 if not _failures else 1)


func _mine() -> void:
	var battle := Battle.new()
	battle.bounds = Rect2(-100, -100, 200, 200)
	var guard := Encounter.new(Vector2.ZERO)
	guard.aggro_sight = _sight
	guard.hold_story_lane = true
	battle.hero_position = Vector2(50.01, 0)
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.WATCHING, "Mine: outside 50 m an eligible player is not acquired.")
	battle.hero_position = Vector2(49.99, 0)
	_visible = false
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.WATCHING, "Mine: within 50 m, opaque geometry still prevents acquisition.")
	battle.hero_position = Vector2(50, 0)
	_visible = true
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.ALERT and guard.enemy_heading == Vector2.RIGHT
		and guard.alert_target == Encounter.Target.HERO,
		"Mine: at 50 m the campaign guard locks and faces a target through independent sight.")
	_tick(guard, battle, 1.0)
	_check(guard.enemy_position == Vector2.ZERO and guard.windup_target == Encounter.Target.NONE and guard.hero.hp == Encounter.HERO_HP,
		"Mine: alerted campaign guard never runs off its authored lane or deals damage at range.")
	battle.hero_position = Vector2(0, 50.01)
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.WATCHING and guard.alert_target == Encounter.Target.NONE,
		"Mine: moving outside 50 m clears a distant alert and target lock.")
	guard.stage_interception(PackedVector2Array([Vector2(4, 0)]))
	battle.hero_position = Vector2(0, 2)
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.AT_RESERVE, "Mine: a visible 2m player cannot bypass the authored reserve activation.")
	_check(guard.begin_interception(), "Mine: the separately authored interception can still issue orders.")
	_tick(guard, battle, 1.0)
	_check(guard.enemy_position == Vector2(4, 0) and guard.enemy_phase == Encounter.EnemyPhase.WATCHING,
		"Mine: fixed route reaches its genuine road post before starting ordinary proximity logic.")
	battle.hero_position = Vector2(3, 0)
	_melee = true
	_tick(guard, battle)
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.WINDUP and guard.hero.hp == Encounter.HERO_HP,
		"Mine: real melee range starts a telegraph and never skips its windup.")
	_tick(guard, battle, Encounter.WINDUP_TIME + DT)
	_check(guard.hero.hp < Encounter.HERO_HP, "Mine: damage is resolved only after a legal contact and the full windup.")
	_melee = false
	guard = Encounter.new(Vector2.ZERO)
	guard.aggro_sight = _sight
	battle.hero_position = Vector2(49.99, 0)
	_tick(guard, battle)
	_tick(guard, battle, 1.0)
	_check(guard.enemy_phase == Encounter.EnemyPhase.PURSUING and guard.enemy_position.x > 0 and guard.hero.hp == Encounter.HERO_HP,
		"Mine practice: an unbounded eligible guard physically pursues inside 50 m.")
	battle.hero_position = Vector2(90, 0)
	battle.formations[0].position = Vector2(0, 50)
	battle.formations[0].order = Battle.Order.HOLD
	guard = Encounter.new(Vector2.ZERO)
	guard.aggro_sight = _sight
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.WATCHING, "Mine: Hold does not create a new retaliation target.")
	battle.formations[0].order = Battle.Order.ATTACK
	_tick(guard, battle)
	_check(guard.enemy_phase == Encounter.EnemyPhase.PURSUING, "Mine: a living attack-ordered formation is eligible at 50 m.")


func _quay() -> void:
	var field := Node3D.new()
	var ground := TestQuayTerrain.new(field)
	var battle := Battle.new()
	for group in battle.formations:
		group.defeat()
	var levy := Levy.new(PackedVector2Array([Vector2.ZERO]), ground)
	battle.hero_position = Vector2(50.01, 0)
	levy.advance(DT, battle, true)
	_check(levy.decision.intent == Patrol.Intent.PATROL and levy.decision.visible_contacts.is_empty(),
		"Quay: outside 50 m even a clear sighting isn't a valid contact.")
	battle.hero_position = Vector2(49.99, 0)
	ground.visible = false
	levy.advance(DT, battle, true)
	_check(levy.decision.intent == Patrol.Intent.PATROL, "Quay: opaque cover rejects acquisition within 50 m.")
	battle.hero_position = Vector2(50, 0)
	ground.visible = true
	levy.advance(DT, battle, true)
	_check(levy.decision.intent == Patrol.Intent.ALERT and levy.decision.contact_id == Levy.HERO_ID
		and levy.decision.visible_contacts.size() == 1 and levy.heading == Vector2.RIGHT
		and not levy.decision.has_destination,
		"Quay: acquisition at exactly 50 m locks and faces the hostile, without a false melee destination.")
	var mobile := Levy.new(PackedVector2Array([Vector2.ZERO, Vector2(0, 12)]), ground)
	mobile.advance(DT, battle, true)
	_check(mobile.position == Vector2.ZERO and mobile.heading == Vector2.RIGHT,
		"Quay: distant alarm physically interrupts its road march while it identifies the threat.")
	for frame in range(60):
		mobile.advance(DT, battle, true)
	_check(mobile.position.x == 0.0 and mobile.position.y > 0.0,
		"Quay: after the alert stance it resumes only its authored route.")
	levy.advance(8.0, battle, true)
	_check(levy.position == Vector2.ZERO, "Quay: a distant alert cannot displace the levy outside its pursuit bounds.")
	battle.formations[0].order = Battle.Order.HOLD
	battle.formations[0].position = Vector2(0, 0.65)
	levy.advance(DT, battle, true)
	_check(levy.decision.intent == Patrol.Intent.ENGAGE and levy.decision.contact_id == StringName(battle.formations[0].title),
		"Quay: an actual close platoon takes priority over an existing distant sighting.")
	field.free()


func _writ() -> void:
	var writer := TestWrit.new()
	var look := Node3D.new()
	root.add_child(look)
	writer._lookout = look
	_check(not writer._seen_from_lookout(Vector3(50.01, 0, 0), Writ.DETECT_RANGE),
		"Writ sentry: a clear target at 50.01 m cannot accumulate the reserve warning.")
	_check(writer._seen_from_lookout(Vector3(50, 3, 0), Writ.DETECT_RANGE),
		"Writ sentry: exactly 50 m in terrain-plan distance is eligible even uphill.")
	writer.clear = false
	_check(not writer._seen_from_lookout(Vector3(49.99, 0, 0), Writ.DETECT_RANGE),
		"Writ sentry: cover at 49.99 m still blocks the separately debounced signal.")
	writer.free()
	look.free()


func _tick(guard: Encounter, battle: Battle, dt := DT) -> void:
	guard.advance(dt, battle, _contact, func(_a: Vector2, _b: Vector2, _f: bool) -> bool: return true)


func _sight(_a: Vector2, _b: Vector2) -> bool:
	return _visible


func _contact(_a: Vector2, _b: Vector2) -> bool:
	return _melee


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)
