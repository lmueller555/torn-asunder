extends "res://game/overworld/sereth/cut_opening_map.gd"
## This button is an explicit sector transition, not a third 3D anchor.
const Transfer := preload("res://game/overworld/sereth/sereth_passage.gd")
signal boundary_requested(destination: String)
signal boundary_cancel_requested
var _boundary_button: Button
var _boundary_origin := CUT
var _boundary_destination := Transfer.TARGET
var _boundary_pending := false
var _boundary_error := ""

func build() -> bool:
	if not super.build():
		return false
	_boundary_button = Button.new()
	_boundary_button.name = "KeeperPassage"
	_boundary_button.text = "Keeper Boundary Post   [Tab / Y]"
	_boundary_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_boundary_button.offset_left=-344
	_boundary_button.offset_right=-26
	_boundary_button.offset_top=28
	_boundary_button.offset_bottom=67
	_boundary_button.focus_mode=Control.FOCUS_NONE
	_boundary_button.pressed.connect(_choose_boundary)
	_boundary_button.hide()
	add_child(_boundary_button)
	return true

func _choose_boundary() -> void:
	if not _boundary_button.visible or _boundary_pending:
		return
	_boundary_error = ""
	# Same opt-in capability boundary as the shared authored-map controller.
	# Stock #292 has no snap API; explicit button uses the canonical navigator.
	if has_method("_snap_focus"):
		call("_snap_focus",Transfer.TARGET,false)
	else:
		_navigation.select(Transfer.TARGET)
	_refresh()

func set_boundary_pending(active: bool,message := "") -> void:
	_boundary_pending = active
	_boundary_error = message
	_refresh()

func confirm_selection() -> void:
	if _boundary_pending:
		return
	if _navigation and _world.current_waypoint_id()==CUT and _navigation.selected_waypoint_id()==Transfer.TARGET:
		if _navigation.action()==Navigation.Action.TRAVEL:
			boundary_requested.emit(Transfer.TARGET)
		return
	super.confirm_selection()

func _back_or_cancel() -> void:
	if _boundary_pending:
		boundary_cancel_requested.emit()
	else:
		super._back_or_cancel()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		super._unhandled_input(event)
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	if _boundary_pending:
		if (key and key.physical_keycode==KEY_ESCAPE) or (pad and pad.button_index==JOY_BUTTON_B):
			_back_or_cancel()
		get_viewport().set_input_as_handled()
		return
	if _boundary_button.visible and ((key and key.physical_keycode==KEY_TAB) or (pad and pad.button_index==JOY_BUTTON_Y)):
		_choose_boundary()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _refresh() -> void:
	super._refresh()
	if not is_node_ready() or not _navigation or not _boundary_button:
		return
	var here := _world.current_waypoint_id()
	_boundary_button.visible=here==CUT and not _navigation.is_travelling() and CLEAR in _confirmed
	_boundary_button.disabled=_boundary_pending
	if here!=CUT or _navigation.selected_waypoint_id()!=Transfer.TARGET:
		return
	if _boundary_pending:
		confirm_button.text="Preparing Passage…"
		confirm_button.disabled=true
		back_button.text="Cancel Passage"
		status_label.text="Party remains at Still Kingdom Cut until the passage is saved."
	elif _navigation.action()==Navigation.Action.TRAVEL:
		confirm_button.text="Confirm Keeper Passage"
		confirm_button.disabled=false
		status_label.text=_boundary_error if not _boundary_error.is_empty() else "Connected route · Year Four · opens on the campaign map"
	elif _navigation.action()==Navigation.Action.LOCKED:
		confirm_button.text="Requires The Names at the Cut"
		confirm_button.disabled=true
