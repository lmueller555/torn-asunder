extends SceneTree

const Feeder := preload("res://game/battlefield/neris_spanwater_feeder.gd")


func _initialize() -> void:
	var passed := _test_early_river_and_gauge()
	passed = _test_pressure_debris_and_recovery() and passed
	passed = _test_crest_fall_and_retry() and passed
	if passed:
		print("Verified Neris's Spanwater rack, protected boards, independent river events, continuous gauge flow, terminal priority, and retry.")
	quit(0 if passed else 1)


func _test_early_river_and_gauge() -> bool:
	var model := Feeder.new()
	var early := Feeder.Observation.new()
	early.debris_pulse_reached_rack = true
	early.crest_reached_feeder = true
	early.river_at_stage = true
	early.water_at_gauge = true
	early.gauge_credit = 4.0
	early.board_credit = 4.0
	if model.advance(early) != Feeder.Phase.CLEAR_INLET or model.released or model.gauge_progress > 0.0:
		return _fail("Unreleased river observations skipped the initial rack or applied gauge credit.")
	var clear := Feeder.Observation.new()
	clear.rack_interaction_confirmed = true
	clear.board_credit = 1.0
	if model.advance(clear) != Feeder.Phase.FIT_BOARDS or model.board_progress > 0.0:
		return _fail("The initial rack interaction credited work not yet underway.")
	_boards(model, 2.0)
	model.advance(Feeder.Observation.new())
	if model.phase != Feeder.Phase.RAISE_GAUGE or model.released or model.gauge_progress > 0.0:
		return _fail("Finishing boards alone started the river or filled the gauge.")
	var release := Feeder.Observation.new()
	release.spillway_release_started = true
	release.debris_pulse_reached_rack = true
	release.crest_reached_feeder = true
	model.advance(release)
	if not model.released or model.rack != Feeder.Rack.CLEAR or model.phase != Feeder.Phase.RAISE_GAUGE:
		return _fail("Prepared boards failed to protect the rack or the safe crest prematurely cleared.")
	_gauge(model, 0.75)
	_gauge(model, NAN)
	_gauge(model, INF)
	_gauge(model, -2.0)
	if model.gauge_progress != 0.75:
		return _fail("Invalid credits altered the gauge or broke otherwise continuous flow.")
	var dry := Feeder.Observation.new()
	dry.river_at_stage = true
	dry.gauge_credit = 4.0
	if model.advance(dry) != Feeder.Phase.RAISE_GAUGE or model.gauge_progress > 0.0:
		return _fail("Main river stage kept stale flow or filled a dry town gauge.")
	_gauge(model, 0.25, true)
	if model.phase != Feeder.Phase.RAISE_GAUGE or model.gauge_progress != 0.25:
		return _fail("One quarter of fresh gauge flow reused previous credit.")
	_gauge(model, 4.0)
	if model.phase != Feeder.Phase.RAISE_GAUGE or model.gauge_progress != 1.0:
		return _fail("Gauge at its mark without current river stage cleared or overflowed.")
	_gauge(model, 0.0, true)
	if model.phase != Feeder.Phase.SUCCEEDED:
		return _fail("Live feeder flow and river stage did not clear together.")
	var late := Feeder.Observation.new()
	late.neris_fell = true
	if model.advance(late) != Feeder.Phase.SUCCEEDED or model.failure != Feeder.Failure.NONE:
		return _fail("Late observations rewrote a successful terminal result.")
	return true


func _test_pressure_debris_and_recovery() -> bool:
	var model := Feeder.new()
	var clear := Feeder.Observation.new()
	clear.rack_interaction_confirmed = true
	clear.maintenance_contested = true
	if model.advance(clear) != Feeder.Phase.CLEAR_INLET:
		return _fail("A contested rack accepted an interaction.")
	clear.maintenance_contested = false
	model.advance(clear)
	_boards(model, 0.4)
	_boards(model, 1.0, true)
	_boards(model, NAN)
	_boards(model, INF)
	_boards(model, -1.0)
	if model.board_progress != 0.4:
		return _fail("Contested or invalid board input made progress or lost prior work.")
	var pulse := Feeder.Observation.new()
	pulse.spillway_release_started = true
	pulse.debris_pulse_reached_rack = true
	pulse.rack_interaction_confirmed = true
	pulse.board_credit = 1.0
	pulse.water_at_gauge = true
	pulse.gauge_credit = 1.0
	if model.advance(pulse) != Feeder.Phase.CLEAR_DEBRIS or not model.released or model.rack != Feeder.Rack.DEBRIS_JAM:
		return _fail("The release waited for the player, or a same-tick action hid the new jam.")
	if model.board_progress != 0.4 or model.gauge_progress > 0.0:
		return _fail("A jammed feeder gained work/flow, or lost its previous board work.")
	clear.maintenance_contested = true
	if model.advance(clear) != Feeder.Phase.CLEAR_DEBRIS:
		return _fail("A contested fresh jam was cleared prematurely.")
	clear.maintenance_contested = false
	if model.advance(clear) != Feeder.Phase.FIT_BOARDS:
		return _fail("A fresh local interaction did not recover the jam.")
	var duplicate_debris := Feeder.Observation.new()
	duplicate_debris.debris_pulse_reached_rack = true
	duplicate_debris.board_credit = 0.6
	duplicate_debris.water_at_gauge = true
	duplicate_debris.gauge_credit = 1.0
	duplicate_debris.river_at_stage = true
	if model.advance(duplicate_debris) != Feeder.Phase.RAISE_GAUGE or model.rack != Feeder.Rack.CLEAR:
		return _fail("A repeated observation of the same pulse recreated its jam.")
	if model.gauge_progress > 0.0:
		return _fail("Simultaneous gauge input bypassed the newly completed board work.")
	var crest := Feeder.Observation.new()
	crest.crest_reached_feeder = true
	model.advance(crest)
	_gauge(model, 1.0, true)
	return model.phase == Feeder.Phase.SUCCEEDED or _fail("Timely repairs before the crest did not permit a clear.")


func _test_crest_fall_and_retry() -> bool:
	var model := Feeder.new()
	var clear := Feeder.Observation.new()
	clear.rack_interaction_confirmed = true
	model.advance(clear)
	_boards(model, 0.75)
	var crest := Feeder.Observation.new()
	crest.spillway_release_started = true
	crest.crest_reached_feeder = true
	crest.board_credit = 0.25
	crest.river_at_stage = true
	crest.water_at_gauge = true
	crest.gauge_credit = 1.0
	if model.advance(crest) != Feeder.Phase.FAILED or model.failure != Feeder.Failure.FEEDER_BURIED or model.board_progress != 0.75:
		return _fail("Work submitted with the crest prevented burial despite unfinished boards.")
	crest.neris_fell = true
	model.advance(crest)
	if model.failure != Feeder.Failure.FEEDER_BURIED:
		return _fail("A late hero loss rewrote confirmed feeder burial.")
	model.restart()
	if model.released or model.rack != Feeder.Rack.INITIAL_BLOCKAGE or model.gauge_progress > 0.0 or model.board_progress > 0.0 or model.failure != Feeder.Failure.NONE or model.phase != Feeder.Phase.CLEAR_INLET:
		return _fail("Restart left hydraulic or terminal state behind.")
	var pulse := Feeder.Observation.new()
	pulse.spillway_release_started = true
	pulse.debris_pulse_reached_rack = true
	if model.advance(pulse) != Feeder.Phase.CLEAR_DEBRIS:
		return _fail("Retry could not observe the independently scheduled release before initial clearance.")
	var burial := Feeder.Observation.new()
	burial.crest_reached_feeder = true
	burial.rack_interaction_confirmed = true
	if model.advance(burial) != Feeder.Phase.FAILED or model.failure != Feeder.Failure.FEEDER_BURIED:
		return _fail("Crest did not bury a jam before a same-tick clearance could take effect.")
	model.restart()
	model.advance(clear)
	_boards(model, 1.0)
	if model.advance(crest) != Feeder.Phase.FAILED or model.failure != Feeder.Failure.NERIS_FELL:
		return _fail("Neris falling did not win a same-tick clear.")
	return true


func _boards(model: Feeder, credit: float, contested := false) -> void:
	var work := Feeder.Observation.new()
	work.board_credit = credit
	work.maintenance_contested = contested
	model.advance(work)


func _gauge(model: Feeder, credit: float, river_at_stage := false) -> void:
	var flow := Feeder.Observation.new()
	flow.water_at_gauge = true
	flow.river_at_stage = river_at_stage
	flow.gauge_credit = credit
	model.advance(flow)


func _fail(message: String) -> bool:
	push_error(message)
	return false
