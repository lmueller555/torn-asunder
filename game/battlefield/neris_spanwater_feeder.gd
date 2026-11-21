extends RefCounted
## Water at the Town Gauge. The scene owns timing, visible warnings, and the
## shared spillway events. Neither Raska's extraction nor Ilyra's boats gate this lane.

const MISSION_ID := &"neris_spanwater_feeder"

enum Phase { CLEAR_INLET, FIT_BOARDS, CLEAR_DEBRIS, RAISE_GAUGE, SUCCEEDED, FAILED }
enum Rack { INITIAL_BLOCKAGE, CLEAR, DEBRIS_JAM }
enum Failure { NONE, NERIS_FELL, FEEDER_BURIED }


class Observation:
	## A fresh interaction by Neris at the inlet rack, not presence at the gauge.
	var rack_interaction_confirmed := false
	var maintenance_contested := false
	## Actual new guide-board work reported by the protected town workers.
	var board_credit := 0.0
	## Shared physical events, independent of the Dryad player's readiness.
	var spillway_release_started := false
	var debris_pulse_reached_rack := false
	var crest_reached_feeder := false
	var river_at_stage := false
	## Continuous feeder flow at the town gauge and normalized new gauge credit.
	## Zero credit during observed flow is not itself a flow interruption.
	var water_at_gauge := false
	var gauge_credit := 0.0
	var neris_fell := false


var phase: Phase:
	get:
		return _phase

var rack: Rack:
	get:
		return _rack

var failure: Failure:
	get:
		return _failure

var board_progress: float:
	get:
		return _board_progress

var gauge_progress: float:
	get:
		return _gauge_progress

var released: bool:
	get:
		return _released

var _phase := Phase.CLEAR_INLET
var _rack := Rack.INITIAL_BLOCKAGE
var _failure := Failure.NONE
var _board_progress := 0.0
var _gauge_progress := 0.0
var _released := false
var _debris_seen := false
var _crest_seen := false


## Resolve the river's arrivals before this tick's repair. Crest failure wins
## ties: boards and rack must already be ready when the crest reaches them.
func advance(observation: Observation) -> Phase:
	if _phase in [Phase.SUCCEEDED, Phase.FAILED]:
		return _phase
	if observation.neris_fell:
		return _fail(Failure.NERIS_FELL)

	_released = _released or observation.spillway_release_started
	var jammed_this_tick := false
	if _released and observation.debris_pulse_reached_rack and not _debris_seen and not _crest_seen:
		_debris_seen = true
		if _board_progress < 1.0:
			_rack = Rack.DEBRIS_JAM
			jammed_this_tick = true
	if _released and observation.crest_reached_feeder and not _crest_seen:
		_crest_seen = true
		if not _feeder_ready():
			return _fail(Failure.FEEDER_BURIED)

	# Do not credit boards before a prior rack clearance, or clear a new jam
	# before the player can see it and make a fresh interaction.
	var feeder_was_ready := _feeder_ready()
	var rack_was_clear := _rack == Rack.CLEAR
	if not observation.maintenance_contested:
		if not rack_was_clear and not jammed_this_tick and observation.rack_interaction_confirmed:
			_rack = Rack.CLEAR
		if rack_was_clear:
			_board_progress = _add_credit(_board_progress, observation.board_credit)

	# Repairs are now in place for subsequent flow, not for credit that
	# might have been sampled before the work on this tick.
	if _released and feeder_was_ready and observation.water_at_gauge:
		_gauge_progress = _add_credit(_gauge_progress, observation.gauge_credit)
	else:
		_gauge_progress = 0.0

	if _rack == Rack.INITIAL_BLOCKAGE:
		_phase = Phase.CLEAR_INLET
	elif _rack == Rack.DEBRIS_JAM:
		_phase = Phase.CLEAR_DEBRIS
	elif _board_progress < 1.0:
		_phase = Phase.FIT_BOARDS
	elif observation.river_at_stage and _gauge_progress >= 1.0:
		_phase = Phase.SUCCEEDED
	else:
		_phase = Phase.RAISE_GAUGE
	return _phase


func restart() -> void:
	_phase = Phase.CLEAR_INLET
	_rack = Rack.INITIAL_BLOCKAGE
	_failure = Failure.NONE
	_board_progress = 0.0
	_gauge_progress = 0.0
	_released = false
	_debris_seen = false
	_crest_seen = false


func _feeder_ready() -> bool:
	return _rack == Rack.CLEAR and _board_progress >= 1.0


func _add_credit(progress: float, credit: float) -> float:
	if not is_finite(credit) or credit <= 0.0:
		return progress
	var advanced := minf(progress + credit, 1.0)
	return 1.0 if is_equal_approx(advanced, 1.0) else advanced


func _fail(reason: Failure) -> Phase:
	_failure = reason
	_phase = Phase.FAILED
	return _phase
