extends "res://game/combat/heavy_defeat_retirement_view.gd"
## Command-camera defeat geometry shares the live Heavy rig and one material palette.
const COMMAND_MODEL_PATH := "res://assets/models/human_heavy_infantry_defeat_command.glb"
const COMMAND_ENTER_WIDTH := 31.0
const COMMAND_EXIT_WIDTH := 29.0

var command_meshes: Dictionary[int, MeshInstance3D] = {}
var command_original_visibility: Dictionary[int, Array] = {}
var command_ready := false
var command_failure := ""
var command_using_far := false
var command_fall_count := 0

func _ready() -> void:
	super._ready()
	if retirement_ready:
		command_ready = _bind_command()
		if not command_ready:
			# The full-wave opaque fallback is outside the audited budget.
			# Keep the original Heavy no-corpse behavior on an invalid donor.
			_reject_retirement(command_failure)

func _bind_command() -> bool:
	var resource := load(COMMAND_MODEL_PATH) as PackedScene
	if resource == null:
		command_failure = "Heavy defeat command geometry is unavailable."
		return false
	var donor_root := resource.instantiate() as Node3D
	var donors := donor_root.find_children("*", "MeshInstance3D", true, false)
	var skels := donor_root.find_children("*", "Skeleton3D", true, false)
	if donors.size() != 1 or skels.size() != 1:
		donor_root.free()
		command_failure = "Witness must contain one weighted mesh and one source rig."
		return false
	var donor := donors[0] as MeshInstance3D
	var src := skels[0] as Skeleton3D
	var shared_mesh := donor.mesh
	var shared_skin := donor.skin
	if shared_mesh == null or shared_mesh.get_surface_count() != 1 or shared_skin == null \
			or donor.transform != Transform3D.IDENTITY or src.transform != Transform3D.IDENTITY:
		donor_root.free()
		command_failure = "Witness is not one origin-aligned independently packed skin."
		return false
	for index: int in retirement_slots:
		var slot: HeavyDisplay = retirement_slots[index]
		var skel := _matching_heavy_rig(slot, src, shared_skin)
		if skel == null:
			donor_root.free()
			command_failure = "Witness source Skin does not exactly bind live Heavy at %d." % index
			return false
	donor_root.free()
	for index: int in retirement_slots:
		var slot: HeavyDisplay = retirement_slots[index]
		var skel := slot.root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := MeshInstance3D.new()
		mesh.name = "HeavyCommandDefeat"
		mesh.mesh = shared_mesh
		mesh.skin = shared_skin
		mesh.skeleton = NodePath("..")
		mesh.set_surface_override_material(0, retirement_source)
		mesh.cast_shadow = slot.surfaces[0].cast_shadow
		mesh.hide()
		skel.add_child(mesh)
		command_meshes[index] = mesh
		command_original_visibility[index] = slot.surfaces.map(func(original): return original.visible)
	return true

func _matching_heavy_rig(slot: HeavyDisplay, src: Skeleton3D, shared_skin: Skin) -> Skeleton3D:
	var skels := slot.root.find_children("*", "Skeleton3D", true, false)
	if skels.size() != 1:
		return null
	var skel := skels[0] as Skeleton3D
	if skel.get_bone_count() != src.get_bone_count() or shared_skin.get_bind_count() != src.get_bone_count():
		return null
	for bone in src.get_bone_count():
		if skel.get_bone_name(bone) != src.get_bone_name(bone) \
				or skel.get_bone_parent(bone) != src.get_bone_parent(bone) \
				or not skel.get_bone_rest(bone).is_equal_approx(src.get_bone_rest(bone)):
			return null
	for surface: MeshInstance3D in slot.surfaces:
		if surface.cast_shadow != slot.surfaces[0].cast_shadow:
			return null
		var stock_skin := surface.skin
		if stock_skin.get_bind_count() != shared_skin.get_bind_count():
			return null
		for bind in shared_skin.get_bind_count():
			if shared_skin.get_bind_name(bind) != stock_skin.get_bind_name(bind) \
					or not shared_skin.get_bind_pose(bind).is_equal_approx(stock_skin.get_bind_pose(bind)):
				return null
	return skel

func _frame_battle(delta: float) -> void:
	super._frame_battle(delta)
	if not command_ready:
		return
	var bounds_aspect: float = get_viewport().get_visible_rect().size.aspect()
	var width: float = _camera.size * (bounds_aspect if _camera.keep_aspect == Camera3D.KEEP_HEIGHT else 1.0)
	command_using_far = width >= (COMMAND_EXIT_WIDTH if command_using_far else COMMAND_ENTER_WIDTH)
	_apply_command_visibility()

func _apply_command_visibility() -> void:
	command_fall_count = 0
	for index: int in command_meshes:
		var slot: HeavyDisplay = retirement_slots[index]
		var mesh := command_meshes[index]
		var select := command_using_far and slot.phase in [Stage.FALL, Stage.SETTLE, Stage.TAPER]
		if mesh.visible != select:
			mesh.visible = select
			for j in slot.surfaces.size():
				slot.surfaces[j].visible = not select and command_original_visibility[index][j]
		if select:
			command_fall_count += 1
			var palette_material := retirement_palette[slot.tier]
			if mesh.get_surface_override_material(0) != palette_material:
				mesh.set_surface_override_material(0, palette_material)

func restart() -> void:
	command_using_far = false
	super.restart()
