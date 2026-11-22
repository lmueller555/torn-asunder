extends SceneTree
## Exercise the normal registered view, not a script swapped by a test harness.
const B := preload("res://game/combat/infantry_skirmish.gd")
const Stock := preload("res://game/combat/infantry_skirmish_view.gd")
const Scene := preload("res://game/combat/infantry_skirmish_view.tscn")
const Display := preload("res://game/combat/infantry_skirmish_defeat_view.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")
const DT := 1.0 / 60.0
var failed := false


class BrokenDonor:
	extends Display

	func _bind_command() -> bool:
		command_failure = "Deliberately unavailable test donor"
		return false


func _initialize() -> void:
	_run.call_deferred()


func _require(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		printerr(detail)


func _run() -> void:
	var setup := Setup.new()
	setup.sides[0][0].set_level(10)
	setup.sides[0][0].set_points(Unit.Damage.MELEE, 9)
	_require(setup.sides[0][0].set_unit_type(Catalog.HUMAN_HEAVY_INFANTRY), "Legal Heavy Infantry build failed")
	var authored := Scene.instantiate() as Display
	var base := Scene.instantiate() as Stock
	base.set_script(Stock)
	for view: Stock in [authored, base]:
		view.configure(setup)
		root.add_child(view)
		view.set_physics_process(false)
		_prepare(view)
	_require(authored.retirement_ready and authored.command_ready, authored.retirement_failure + authored.command_failure)
	if not authored.retirement_ready or not authored.command_ready:
		quit(1)
		return
	var record: Display.HeavyDisplay = authored.retirement_slots[0]
	var first_steps := [-1, -1, -1, -1, -1]
	var seen_tiers: Array[int] = []
	var paused_phases: Array[int] = []
	for tick in 121:
		for view: Stock in [authored, base]:
			view._physics_process(DT)
		_require(_same_gameplay(authored, base), "Solver or marker changed at tick %d" % tick)
		if tick == 0:
			_require(authored.battle.hits == 2 and authored.battle.winner == B.DRAW and not authored._markers[0].visible,
				"Expected reciprocal authoritative lethal contacts and a draw")
		if first_steps[record.phase] == -1:
			first_steps[record.phase] = tick
		var anim := authored._players[0]
		match record.phase:
			Display.Stage.FALL:
				_require(anim.assigned_animation == Display.DEFEAT and record.root.visible
					and absf(anim.current_animation_position - authored.battle.soldiers[0].time) < 0.00001,
					"Heavy Fall does not track exact lethal-state clock")
			Display.Stage.SETTLE, Display.Stage.TAPER:
				_require(record.root.visible and is_equal_approx(anim.current_animation_position, 1.20),
					"The body must hold exact grounded frame before hide")
				if record.phase == Display.Stage.TAPER and record.tier not in seen_tiers:
					seen_tiers.append(record.tier)
			Display.Stage.RETIRED:
				_require(not record.root.visible and not authored.command_meshes[0].visible
					and authored._models[32].visible and base._models[32].visible,
					"Only the retired Heavy, not regular corpses, should disappear")
		if record.phase in [Display.Stage.FALL, Display.Stage.SETTLE, Display.Stage.TAPER] and record.phase not in paused_phases:
			paused_phases.append(record.phase)
			authored.paused = true
			var time_before: float = record.post_landing_s
			var pose_before: float = anim.current_animation_position
			authored._physics_process(DT * 4.0)
			_require(record.post_landing_s == time_before and anim.current_animation_position == pose_before and _same_gameplay(authored,base),
				"Pause advanced a defeat phase")
			authored.paused = false
	_require(first_steps == [-1, 0, 72, 96, 114] and seen_tiers == [0,1,2,3,4,5,6,7,8,9,10,11],
		"Heavy fade boundaries/tiers changed: %s, %s" % [first_steps, seen_tiers])
	_require(authored.retirement_slots.size() == 32 and authored.command_meshes.size() == 32, "Mixed team mesh scope")
	authored.restart()
	_require(record.root.visible and authored._markers[0].visible and not authored.command_meshes[0].visible
		and record.phase == Display.Stage.LIVE and authored._players[0].assigned_animation == &"Shield-Ready Idle",
		"Retry must restore alive marker, exact Ready and no command corpse")
	_check_missing_donor(setup)
	authored.queue_free()
	base.queue_free()
	await process_frame
	if not failed:
		print("Defeat: 121 authority-equivalent mixed steps; real reciprocal loss, pause, 72/96/114, regular corpse, Retry, and fail-closed command donor.")
	quit(1 if failed else 0)


func _prepare(view: Stock) -> void:
	for actor: B.Soldier in view.battle.soldiers:
		if actor.battle_index not in [0, 32]:
			actor.unit.receive_damage(actor.unit.hp)
			actor.state = B.State.DEAD
			actor.time = B.DURATIONS[B.State.DEAD]
	for index in [0, 32]:
		var actor: B.Soldier = view.battle.soldiers[index]
		var opponent: B.Soldier = view.battle.soldiers[32 - index]
		actor.position = Vector2(0, -0.55 if index == 0 else 0.55)
		actor.facing = Vector2.DOWN if index == 0 else Vector2.UP
		actor.target = opponent.battle_index
		actor.state = B.State.ATTACK
		actor.time = B.CONTACT - DT * 0.5
		var incoming: float = actor.unit.damage_from(opponent.unit, opponent.basic_attack)
		actor.unit.receive_damage(actor.unit.hp - incoming * 0.45)
	view.battle._index_bodies()
	view._sync_models(0.0)


func _same_gameplay(a: Stock, b: Stock) -> bool:
	if a.battle.winner != b.battle.winner or a.battle.elapsed != b.battle.elapsed or a.battle.hits != b.battle.hits:
		return false
	for index in a.battle.soldiers.size():
		var x := a.battle.soldiers[index]
		var y := b.battle.soldiers[index]
		if x.state != y.state or x.time != y.time or x.unit.hp != y.unit.hp or x.position != y.position \
				or x.facing != y.facing or x.victory_cheers != y.victory_cheers \
				or a._markers[index].visible != b._markers[index].visible:
			return false
	return true


func _check_missing_donor(setup: Setup) -> void:
	var view := Scene.instantiate() as Display
	view.set_script(BrokenDonor)
	view.configure(setup)
	root.add_child(view)
	view.set_physics_process(false)
	_prepare(view)
	view._physics_process(DT)
	_require(not view.command_ready and not view.retirement_ready and view.retirement_slots.is_empty()
		and view.command_meshes.is_empty() and view.retirement_palette.is_empty() and view.retirement_cutout == null,
		"An invalid command donor must disable the costly full-wave defeat presentation")
	_require(view.battle.hits == 2 and view.battle.winner == B.DRAW and not view._models[0].visible
		and not view._markers[0].visible and view._models[32].visible,
		"Failed donor must preserve both resolver outcomes, markers and regular corpse")
	view.queue_free()
