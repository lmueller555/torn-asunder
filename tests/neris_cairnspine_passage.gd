extends SceneTree

const Passage := preload("res://game/battlefield/neris_cairnspine_passage.gd")
const Group := Passage.Group
const Status := Passage.Status
const Route := Passage.Route
const Outcome := Passage.Outcome
const Failure := Passage.Failure

var _failures := 0


func _initialize() -> void:
	_check_guides_and_routes()
	_check_shared_road(Route.SHELF, Route.SIDE, false)
	_check_shared_road(Route.SIDE, Route.SIDE, true)
	_check_shared_road(Route.SHELF, Route.SHELF, true)
	_check_recovery()
	_check_losses_and_retry()
	if _failures == 0:
		print("Neris passage: separate guides and arrivals, either route and one shared route, live screening and rerouting, genuine losses, independent victory and retry passed.")
	quit(0 if _failures == 0 else 1)


func _check_guides_and_routes() -> void:
	var mission := Passage.new()
	var frame := _open_frame()
	frame.witness_guide_signaled = true
	frame.witnesses.route_confirmed = Route.SIDE
	frame.witnesses.terrace_reached = true
	frame.refugees.route_confirmed = Route.SHELF
	frame.refugees.terrace_reached = true
	mission.advance(frame)
	_check(mission.group_status(Group.REFUGEES) == Status.STAGED
		and mission.group_status(Group.WITNESSES) == Status.STAGED,
		"Premature guide signal, route choice or arrival must not be queued.")
	frame.refugee_guide_met = true
	mission.advance(frame)
	_check(mission.group_status(Group.REFUGEES) == Status.WAITING
		and mission.group_status(Group.WITNESSES) == Status.STAGED
		and mission.group_route(Group.REFUGEES) == Route.NONE, "The first guide does not double as a route or witness order.")
	frame = _open_frame()
	frame.refugees.route_confirmed = Route.SHELF
	frame.refugees.shelf_open = false
	frame.refugees.terrace_reached = true
	mission.advance(frame)
	mission.advance(_open_frame())
	_check(mission.group_status(Group.REFUGEES) == Status.WAITING
		and mission.group_route(Group.REFUGEES) == Route.NONE, "An unsafe attempt starts moving when it opens without fresh confirmation.")
	frame.refugees.shelf_open = true
	mission.advance(frame)
	_check(mission.group_status(Group.REFUGEES) == Status.MOVING
		and mission.may_advance(Group.REFUGEES), "One route interaction should command movement, never teleport the group to safety.")


func _check_shared_road(refugee_route: Passage.Route, witness_route: Passage.Route, witnesses_first: bool) -> void:
	var mission := Passage.new()
	_readied_parties(mission)
	var frame := _open_frame(refugee_route == Route.SHELF or witness_route == Route.SHELF,
		refugee_route == Route.SIDE or witness_route == Route.SIDE)
	frame.refugees.route_confirmed = refugee_route
	frame.witnesses.route_confirmed = witness_route
	mission.advance(frame)
	_check(mission.group_route(Group.REFUGEES) == refugee_route
		and mission.group_route(Group.WITNESSES) == witness_route
		and mission.may_advance(Group.REFUGEES) and mission.may_advance(Group.WITNESSES), "Both parties need separately actionable lane clearance.")
	frame.refugees.route_confirmed = Route.NONE
	frame.witnesses.route_confirmed = Route.NONE
	frame.refugees.terrace_reached = not witnesses_first
	frame.witnesses.terrace_reached = witnesses_first
	var first := Group.WITNESSES if witnesses_first else Group.REFUGEES
	var second := Group.REFUGEES if witnesses_first else Group.WITNESSES
	mission.advance(frame)
	_check(mission.outcome == Outcome.ACTIVE and mission.group_status(first) == Status.SAFE
		and not mission.may_advance(first) and mission.may_advance(second), "One physical arrival should not clear the mission.")
	frame.refugees.terrace_reached = witnesses_first
	frame.witnesses.terrace_reached = not witnesses_first
	frame.refugees.lost = not witnesses_first
	frame.witnesses.lost = witnesses_first
	mission.advance(frame)
	_check(mission.outcome == Outcome.SUCCEEDED and mission.failure == Failure.NONE
		and mission.group_status(second) == Status.SAFE and not mission.may_advance(second),
		"Both arrivals must win without any vault or court state; an already safe party cannot be lost.")
	frame.neris_fell = true
	mission.advance(frame)
	_check(mission.outcome == Outcome.SUCCEEDED and mission.failure == Failure.NONE, "An achieved victory must be terminal.")


func _check_recovery() -> void:
	var mission := Passage.new()
	_readied_parties(mission)
	var frame := _open_frame()
	frame.refugees.route_confirmed = Route.SHELF
	frame.witnesses.route_confirmed = Route.SIDE
	mission.advance(frame)
	frame = _open_frame()
	frame.refugees.shelf_open = false
	frame.refugees.side_open = false
	frame.refugees.terrace_reached = true
	frame.refugees.route_confirmed = Route.SIDE
	for _tick in range(100):
		mission.advance(frame)
	_check(mission.outcome == Outcome.ACTIVE and mission.group_status(Group.REFUGEES) == Status.BLOCKED
		and mission.group_route(Group.REFUGEES) == Route.SHELF and not mission.may_advance(Group.REFUGEES)
		and mission.may_advance(Group.WITNESSES), "Threat should park only the affected party, not force an unsafe reroute or timed loss.")

	frame = _open_frame()
	frame.refugees.terrace_reached = true
	frame.witnesses.side_open = false
	mission.advance(frame)
	_check(mission.may_advance(Group.REFUGEES) and mission.group_status(Group.WITNESSES) == Status.BLOCKED
		and mission.group_route(Group.WITNESSES) == Route.SIDE, "An existing route should resume when screened, without accepting the stale terrace flag.")
	frame.witnesses.route_confirmed = Route.SHELF
	frame.witnesses.terrace_reached = true
	mission.advance(frame)
	_check(mission.group_status(Group.REFUGEES) == Status.SAFE and mission.may_advance(Group.WITNESSES)
		and mission.group_route(Group.WITNESSES) == Route.SHELF and mission.outcome == Outcome.ACTIVE,
		"Fresh confirmation should reroute the threatened witnesses without treating it as their arrival.")
	frame = _open_frame()
	frame.witnesses.terrace_reached = true
	mission.advance(frame)
	_check(mission.outcome == Outcome.SUCCEEDED, "The recovered route must deliver witnesses independently.")


func _check_losses_and_retry() -> void:
	var mission := Passage.new()
	for failure: Passage.Failure in [Failure.REFUGEES_LOST, Failure.WITNESSES_LOST, Failure.NERIS_FELL]:
		_readied_parties(mission)
		var frame := _open_frame()
		frame.refugees.route_confirmed = Route.SHELF
		frame.witnesses.route_confirmed = Route.SIDE
		mission.advance(frame)
		frame = _open_frame()
		frame.refugees.lost = failure == Failure.REFUGEES_LOST
		frame.witnesses.lost = failure == Failure.WITNESSES_LOST
		frame.neris_fell = failure == Failure.NERIS_FELL
		frame.refugees.terrace_reached = true
		frame.witnesses.terrace_reached = true
		mission.advance(frame)
		_check(mission.outcome == Outcome.FAILED and mission.failure == failure
			and not mission.may_advance(Group.REFUGEES) and not mission.may_advance(Group.WITNESSES),
			"Definitive group loss or hero defeat must beat a would-be same-tick success.")
		if frame.refugees.lost:
			_check(mission.group_status(Group.REFUGEES) == Status.LOST, "Refugees were not marked lost.")
		if frame.witnesses.lost:
			_check(mission.group_status(Group.WITNESSES) == Status.LOST, "Witnesses were not marked lost.")
		mission.advance(_open_frame())
		_check(mission.outcome == Outcome.FAILED and mission.failure == failure, "Failure must be terminal.")
		mission.restart()
		_check(mission.outcome == Outcome.ACTIVE and mission.failure == Failure.NONE
			and mission.group_status(Group.REFUGEES) == Status.STAGED and mission.group_status(Group.WITNESSES) == Status.STAGED
			and mission.group_route(Group.REFUGEES) == Route.NONE and mission.group_route(Group.WITNESSES) == Route.NONE,
			"Retry must reset both guides, parties, routes and result.")


func _readied_parties(mission: Passage) -> void:
	var frame := _open_frame()
	frame.refugee_guide_met = true
	mission.advance(frame)
	frame.refugee_guide_met = false
	frame.witness_guide_signaled = true
	mission.advance(frame)
	_check(mission.group_status(Group.REFUGEES) == Status.WAITING
		and mission.group_status(Group.WITNESSES) == Status.WAITING, "Both guides should respond without waiting for either arrival.")


func _open_frame(shelf := true, side := true) -> Passage.Observation:
	var frame := Passage.Observation.new()
	frame.refugees.shelf_open = shelf
	frame.refugees.side_open = side
	frame.witnesses.shelf_open = shelf
	frame.witnesses.side_open = side
	return frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
