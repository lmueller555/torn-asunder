extends Node3D

# Only this visual child moves. The escort script owns the anchor, objective,
# beacons and range. Camera mode selects the authored alternate mesh directly.
var _case: MeshInstance3D
var _tactical_case: MeshInstance3D
var _keeper: MeshInstance3D


func _init(model: Node3D) -> void:
	name = &"CustodyCaseVisual"
	add_child(model)
	_case = model.get_node(^"Custody_Near") as MeshInstance3D
	_tactical_case = model.get_node(^"Custody_Far") as MeshInstance3D
	_keeper = model.get_node(^"Custody_Carry_Loop") as MeshInstance3D


func present(carrying: bool, tactical: bool) -> void:
	_case.visible = not tactical
	_tactical_case.visible = tactical
	_keeper.visible = carrying and not tactical
	if carrying:
		# The case's keeper threads the handle and seats against the carrier.
		rotation = Vector3(0.0, deg_to_rad(62.0), 0.0)
		position = Vector3(0.170, -0.10, 0.035)
	else:
		# Stand beside, rather than in, the existing gold beacon.
		rotation = Vector3(0.0, deg_to_rad(-73.0), 0.0)
		position = Vector3(0.0, -0.75 + 0.1185, -0.47)
