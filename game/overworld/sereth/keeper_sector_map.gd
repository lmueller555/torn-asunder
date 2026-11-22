extends "res://game/overworld/sereth/keeper_view.gd"
## Reuses one approved common sector control. With two ordinary exits, Tab/Y
## cycles its selection; Confirm still travels only on the selected edge.
var _published_exits: Array[String] = []

func install_exits(exits: Array[String]) -> void:
	if exits.is_empty():
		return
	_published_exits=exits.duplicate()
	install_boundary_selector(Passage.TARGET,exits[0],_exit_label(exits[0]))
	if exits.size()>1:
		_boundary_button.text="Choose sector passage   [Tab / Y]"

func _exit_label(id: String) -> String:
	return "Return to Still Kingdom Cut" if id==Passage.ORIGIN else "Continue to Valley Assembly"

func _choose_boundary() -> void:
	if _boundary_pending or _published_exits.is_empty() or _world.current_waypoint_id()!=Passage.TARGET:
		return
	_boundary_error=""
	var slot := _published_exits.find(_navigation.selected_waypoint_id())
	_boundary_destination=_published_exits[(slot+1)%_published_exits.size()]
	_boundary_button.text=_exit_label(_boundary_destination)+"   [Tab / Y]"
	_snap_focus(_boundary_destination,false)
