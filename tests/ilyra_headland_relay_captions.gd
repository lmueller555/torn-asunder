extends "res://tests/ilyra_coast_survey_campaign.gd"
## Presentation-only regression at the original Headland and Beach sites.

func _run() -> void:
	_mission = Scene.instantiate()
	root.add_child(_mission)
	_mission.set_physics_process(false)
	await physics_frame
	await physics_frame
	_mission.mission_cleared.connect(func(value: StringName) -> void: _results.append(value))
	var ok := _check_headland_billboards() and _check_beach_billboard_presentation()
	if ok:
		ok = _visit_both() and _take_headland_for_test() and _check_retry()
	_mission.queue_free()
	await process_frame
	if ok:
		print("Headland captions: exactly two original labels, far/fade/close, immediate tactical restore, Beach unchanged, parent/active cue preserved and actual clear/retry passed.")
	quit(0 if ok else 1)


func _check_headland_billboards() -> bool:
	var high := _mission._headland_billboards
	if high.size() != 2 or high[0].label.get_parent() != _mission._signal_flags[1] \
			or high[1].label.get_parent() != _mission._crews[1] \
			or high[0].label.text != "HEADLAND SIGNAL" or high[1].label.text != "Landward port crew":
		return _fail("Only the original high relay and measured landward crew captions should bind.")
	if not _walk_routes(STONE_PATH + INLET_PATH + HEADLAND_PATH.slice(0, -1)):
		return false
	if not _full_style(high) or _mission._crews[1].visible:
		return _fail("Both source caption styles stay at high guard; the dormant crew stays absent.")
	var guard := _point("Routes/HighGuard")
	var ring := _point("Objectives/HeadlandSignal")
	if not _walk_to(guard.lerp(ring, 0.375)):
		return false
	for style in high:
		if not style.label.visible or style.label.modulate.a <= 0.1 or style.label.modulate.a >= 0.9 \
				or not is_equal_approx(style.label.outline_modulate.a, style.outline.a * style.label.modulate.a):
			return _fail("High text and outline fade smoothly on the actual walk.")
	if not _walk_routes(HEADLAND_PATH.slice(-1)):
		return false
	var cue := _mission._signal_flags[1]
	var cue_transform := cue.global_transform
	_key(KEY_SPACE)
	_tick()
	if high[0].label.visible or high[1].label.visible or _mission._crews[1].visible \
			or not cue.visible or cue.global_transform != cue_transform \
			or not _mission._hint.text.contains("First find"):
		return _fail("Clear hero close art without changing the beacon, crew or reading lock.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	if not _mission.command_view or not _full_style(high) or _mission._crews[1].visible:
		return _fail("Restore exact tactical styles immediately, not the dormant actor.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	if high[0].label.visible or high[1].label.visible:
		return _fail("Returning to hero must immediately suppress both close captions again.")
	_key(KEY_BACKSPACE)
	return (_fresh_state() and _full_style(high)) or _fail("Retry did not reset the high caption state.")


func _take_headland_for_test() -> bool:
	if not _walk_routes(HEADLAND_PATH) or not _move_detachment(DETACHMENT_ROAD + DETACHMENT_HEADLAND):
		return false
	if not _wait(func() -> bool: return _mission._holding_site == HEADLAND and _mission._clear_signal_ray(1), "headland hold"):
		return false
	_joy(JOY_BUTTON_A)
	_tick(22)
	var cue := _mission._signal_flags[1]
	var high := _mission._headland_billboards
	var progress := _mission.objective.signal_progress
	if _mission.objective.signal_site != HEADLAND or progress <= 0.0 or not is_equal_approx(cue.scale.y, 1.6) \
			or high[0].label.visible or high[1].label.visible or not _mission._crews[1].visible:
		return _fail("Actual transmitted state must raise the cue and keep the crew, not the close captions.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tick()
	if not _full_style(high) or _mission.objective.signal_progress <= progress:
		return _fail("Tactical restore did not preserve the active relay and its progress.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	return _wait(func() -> bool: return _mission.objective.phase == Survey.Phase.SUCCEEDED, "headland acknowledgment") \
		and _results == [Mission.CHART_CIRCULATED]


func _full_style(styles: Array) -> bool:
	for style in styles:
		if style.label.visible != style.visible or style.label.modulate != style.face \
				or style.label.outline_modulate != style.outline:
			return false
	return true
