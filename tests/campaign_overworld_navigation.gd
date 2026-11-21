extends SceneTree

const World := preload("res://game/campaign_world.gd")
const Navigation := preload("res://game/campaign_overworld_navigation.gd")
const CAMP := "marches_camp"
const MINE := "year_one_mine"
const ROAD := "marches_road"
const CROSSING := "marches_crossing"
const CLEAR := "mara_mine_escort"


func _initialize() -> void:
	var passed := _check_travel() and _check_authored_timing() and _check_gates() and _check_direction()
	if passed:
		print("Overworld navigation: one open edge, arrival callback, authored timing, cancel/reset, route gates, and spatial selection passed.")
	quit(0 if passed else 1)


func _check_travel() -> bool:
	var world := World.new("mara")
	var nav := Navigation.new(world, PackedStringArray())
	var arrivals: Array[String] = []
	var callback_state: Array[bool] = []
	var weak_nav: WeakRef = weakref(nav)
	nav.waypoint_arrived.connect(func(id: String) -> void:
		var arriving_nav := weak_nav.get_ref() as Navigation
		arrivals.append(id)
		callback_state.append(world.current_waypoint_id() == id and world.visited_waypoint_ids().has(id)
			and not arriving_nav.is_travelling() and arriving_nav.action() == Navigation.Action.BRIEFING)
		arriving_nav.reset()
	)
	var camp_position: Vector2 = world.waypoint(CAMP).map_position
	var mine_position: Vector2 = world.waypoint(MINE).map_position
	if nav.action() != Navigation.Action.CAMP or not nav.select(MINE) or not nav.start_travel():
		return _fail("Expected departure from camp on its open edge.")
	var default_duration := clampf(camp_position.distance_to(mine_position) / 0.55, 0.35, 1.4)
	nav.advance(default_duration * 0.25)
	if not is_equal_approx(nav.travel_progress(), 0.25):
		return _fail("Omitted duration must retain the normalized map timing.")
	var midpoint := nav.token_map_position()
	if not nav.is_travelling() or nav.select(ROAD) or nav.start_travel() or not arrivals.is_empty() \
			or world.current_waypoint_id() != CAMP or midpoint.is_equal_approx(camp_position) \
			or midpoint.is_equal_approx(mine_position) \
			or not midpoint.is_equal_approx(Geometry2D.get_closest_point_to_segment(midpoint, camp_position, mine_position)):
		return _fail("In-flight travel must remain on the edge, with world state and destination unchanged.")
	if not nav.cancel_travel() or nav.cancel_travel() or nav.selected_waypoint_id() != MINE:
		return _fail("Cancel must leave the destination selected for retry.")
	nav.advance(9.0)
	if nav.token_map_position() != camp_position or not arrivals.is_empty() or not nav.start_travel():
		return _fail("Canceled travel must never commit or notify.")
	nav.reset()
	nav.advance(9.0)
	if nav.selected_waypoint_id() != CAMP or world.current_waypoint_id() != CAMP \
			or world.visited_waypoint_ids() != PackedStringArray([CAMP]) or not arrivals.is_empty():
		return _fail("Reset must clear pending travel and select the committed location.")
	if not nav.select(MINE) or not nav.start_travel():
		return _fail("The canceled trip must remain available.")
	nav.advance(9.0)
	nav.advance(9.0)
	if arrivals != [MINE] or callback_state != [true] or nav.token_map_position() != mine_position \
			or nav.start_travel() or world.mission_at_current_waypoint() != CLEAR:
		return _fail("Exactly one arrival must precede any shell-owned mission action.")
	return true


func _check_authored_timing() -> bool:
	var world := World.new("mara")
	var nav := Navigation.new(world, PackedStringArray())
	var arrivals: Array[String] = []
	nav.waypoint_arrived.connect(func(id: String) -> void: arrivals.append(id))
	if not nav.select(MINE):
		return _fail("Expected a valid destination for authored timing.")
	for invalid: Variant in [0.0, -1.0, INF, -INF, NAN, "4.0"]:
		if nav.start_travel(invalid) or nav.is_travelling():
			return _fail("Invalid authored timing must leave navigation idle.")
	nav.advance(9.0)
	if not arrivals.is_empty() or world.current_waypoint_id() != CAMP or not nav.start_travel(4.0):
		return _fail("Invalid start must not commit and a valid route duration must be accepted.")
	if nav.travel_origin_id() != CAMP or nav.travel_target_id() != MINE or nav.travel_progress() != 0.0:
		return _fail("An active trip must expose its endpoints and zero initial progress.")
	nav.advance(1.0)
	for invalid_delta: float in [0.0, -3.0, INF, -INF, NAN]:
		nav.advance(invalid_delta)
	if nav.start_travel(0.0) or nav.start_travel(1.0) or nav.travel_progress() != 0.25 \
			or nav.travel_origin_id() != CAMP or nav.travel_target_id() != MINE or not arrivals.is_empty():
		return _fail("Invalid deltas and repeated starts must leave active travel untouched.")
	nav.advance(2.0)
	if nav.travel_progress() != 0.75 or world.current_waypoint_id() != CAMP:
		return _fail("Progress must follow authored duration beyond the normalized default.")
	if not nav.cancel_travel() or not _travel_is_idle(nav):
		return _fail("Cancel must clear the renderer's active travel state.")
	if not nav.start_travel(2.0) or nav.travel_progress() != 0.0:
		return _fail("Retry must begin a fresh trip.")
	nav.advance(1.0)
	if nav.travel_progress() != 0.5 or not arrivals.is_empty():
		return _fail("Retry must not inherit elapsed time.")
	nav.advance(1.0)
	if arrivals != [MINE] or world.current_waypoint_id() != MINE or not _travel_is_idle(nav):
		return _fail("Authored travel must commit once at its duration and clear renderer state.")
	return true


func _travel_is_idle(nav: Navigation) -> bool:
	return not nav.is_travelling() and nav.travel_origin_id().is_empty() \
		and nav.travel_target_id().is_empty() and nav.travel_progress() == 0.0


func _check_gates() -> bool:
	var world := World.new("mara", MINE)
	var nav := Navigation.new(world, PackedStringArray())
	var arrivals: Array[String] = []
	nav.waypoint_arrived.connect(func(id: String) -> void: arrivals.append(id))
	if nav.action() != Navigation.Action.BRIEFING or nav.select("unknown") \
			or not nav.select(CROSSING) or nav.action() != Navigation.Action.NO_ROUTE or nav.start_travel() \
			or not nav.select(ROAD) or nav.action() != Navigation.Action.LOCKED or nav.start_travel():
		return _fail("Unknown, nonadjacent and locked destinations must never start travel.")
	nav.set_completed_ids(PackedStringArray([CLEAR]))
	if not nav.start_travel():
		return _fail("An authoritative clear must unlock the route.")
	nav.set_completed_ids(PackedStringArray())
	nav.advance(9.0)
	if nav.is_travelling() or world.current_waypoint_id() != MINE or not arrivals.is_empty() \
			or world.visited_waypoint_ids() != PackedStringArray([CAMP, MINE]):
		return _fail("A gate that closes before arrival must prevent the commit and callback.")
	nav.set_completed_ids(PackedStringArray([CLEAR]))
	if not nav.start_travel():
		return _fail("Expected to retry the road after the gate opens.")
	nav.advance(9.0)
	if arrivals != [ROAD] or world.current_waypoint_id() != ROAD or nav.action() != Navigation.Action.NONE:
		return _fail("Arrival at a region must be reported without a briefing action.")
	return true


func _check_direction() -> bool:
	var nav := Navigation.new(World.new("mara"), PackedStringArray())
	var projected: Dictionary[String, Vector2] = {
		CAMP: Vector2(100, 100), MINE: Vector2(150, 100), ROAD: Vector2(105, 80),
		CROSSING: Vector2(400, 100), "unknown": Vector2(101, 100),
	}
	if nav.select_in_direction(Vector2.ZERO, projected, 500.0) \
			or not nav.select_in_direction(Vector2.RIGHT, projected, 500.0) \
			or nav.selected_waypoint_id() != MINE:
		return _fail("Directional selection must prefer an aligned nearby known waypoint.")
	projected.erase(MINE)
	if nav.select_in_direction(Vector2.LEFT, projected, 500.0) or nav.selected_waypoint_id() != MINE:
		return _fail("Directional selection needs a projection for the current selection.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
