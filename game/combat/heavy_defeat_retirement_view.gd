extends "res://game/combat/infantry_skirmish_view.gd"
## Heavy defeat presentation. The inherited Skirmish owns all combat state.
const DEFEAT := &"Death Fall"
const SETTLE_SECONDS := 0.40
const TAPER_SECONDS := 0.30
const TAPER_DIVISIONS := 12
const EPSILON := 0.0000001
const EXPECTED_MATERIAL := "Heavy Infantry Painted Armor"
const APPROVED_ALBEDO_PATH := "res://assets/models/heavy_infantry/painted_base_color.png"
const CUTOUT_TEXTURE_PATH := "res://assets/models/heavy_infantry/retirement_cutout.png"
const CUTOUT_SIDE := 2048
const CUTOUT_RESIDENT_BYTES_LIMIT := 22369620
const EXPECTED_MESH_NAMES := ["HeavyInfantryBody", "HeavyInfantryShield", "HeavyInfantrySword"]
enum Stage { LIVE, FALL, SETTLE, TAPER, RETIRED }

class HeavyDisplay:
	var root: Node3D
	var original_visibility: bool
	var surfaces: Array[MeshInstance3D] = []
	var original_overrides: Array[Material] = []
	var phase: int = Stage.LIVE
	var post_landing_s: float = 0.0
	var tier: int = 0

var retirement_ready := false
var retirement_failure := ""
var retirement_slots: Dictionary[int, HeavyDisplay] = {}
var retirement_source: BaseMaterial3D
var retirement_palette: Array[BaseMaterial3D] = []
var retirement_cutout: Texture2D
var retirement_cutout_mip_bytes := 0

func _ready() -> void:
	super._ready()
	# Do not change the shared legacy clip dictionary or other scene owners.
	var clips := HEAVY_CLIPS.duplicate()
	clips[Battle.State.DEAD] = DEFEAT
	for index in _clip_sets.size():
		if battle.soldiers[index].unit_type == Catalog.HUMAN_HEAVY_INFANTRY:
			_clip_sets[index] = clips
	_bind_retirement()

func _bind_retirement() -> void:
	if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "gl_compatibility":
		_reject_retirement("Exact prototype is intended for Compatibility.")
		return
	for index in _models.size():
		if battle.soldiers[index].unit_type != Catalog.HUMAN_HEAVY_INFANTRY:
			continue
		var player := _players[index]
		var clip := _valid_clip(player, _clip_sets[index], Battle.State.DEAD)
		if clip != DEFEAT or not is_equal_approx(player.get_animation(clip).length, 1.2):
			_reject_retirement("Missing exact 1.20 s Heavy Death Fall at %d." % index)
			return
		var slot := HeavyDisplay.new()
		slot.root = _models[index]
		slot.original_visibility = slot.root.visible
		var names: Array[String] = []
		for child in slot.root.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			if mesh == _markers[index]:
				continue
			var name_key := String(mesh.name).replace(" ", "").replace("_", "")
			if name_key not in EXPECTED_MESH_NAMES or name_key in names or mesh.mesh == null \
					or mesh.mesh.get_surface_count() != 1 or mesh.skin == null \
					or mesh.material_override != null or mesh.material_overlay != null:
				_reject_retirement("Unexpected Heavy surface %s at slot %d." % [mesh.name, index])
				return
			var source := mesh.get_active_material(0) as BaseMaterial3D
			if source == null or source.resource_name != EXPECTED_MATERIAL \
					or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
					or not is_equal_approx(source.albedo_color.a, 1.0) \
					or source.albedo_texture == null or source.normal_texture == null \
					or source.albedo_texture.resource_path != APPROVED_ALBEDO_PATH \
					or (retirement_source != null and source != retirement_source):
				_reject_retirement("Unexpected Heavy material on %s at slot %d." % [mesh.name, index])
				return
			retirement_source = source
			names.append(name_key)
			slot.surfaces.append(mesh)
			slot.original_overrides.append(mesh.get_surface_override_material(0))
		if names.size() != EXPECTED_MESH_NAMES.size():
			_reject_retirement("Expected exact Body/Shield/Sword at slot %d; got %s." % [index, names])
			return
		retirement_slots[index] = slot
	if retirement_slots.is_empty():
		_reject_retirement("No Heavy owners were supplied.")
		return
	if not _load_exact_cutout():
		_reject_retirement("The exact approved RGB / bounded spatial cutout pair is unavailable.")
		return
	retirement_palette.append(retirement_source) # zero uses the original assignment
	for tier in range(1, TAPER_DIVISIONS):
		var material := retirement_source.duplicate(false) as BaseMaterial3D
		material.resource_name = "Heavy Defeat Cutout %02d" % tier
		material.albedo_texture = retirement_cutout
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		material.alpha_scissor_threshold = float(tier) / TAPER_DIVISIONS
		retirement_palette.append(material)
	retirement_ready = true

func _load_exact_cutout() -> bool:
	var atlas := load(CUTOUT_TEXTURE_PATH) as Texture2D
	if atlas == null or atlas.get_size() != Vector2(CUTOUT_SIDE, CUTOUT_SIDE):
		return false
	# Texture is lossless imported with the exact reviewed mip chain. The audit
	# receipt pins raw bytes; exported games must not read the source PNG.
	retirement_cutout = atlas
	retirement_cutout_mip_bytes = CUTOUT_RESIDENT_BYTES_LIMIT
	return true

func _reject_retirement(reason: String) -> void:
	retirement_ready = false
	retirement_slots.clear()
	retirement_palette.clear()
	retirement_source = null
	retirement_cutout = null
	retirement_cutout_mip_bytes = 0
	retirement_failure = reason
	# Fall back to earlier Heavy visibility only; regular corpses stay unchanged.
	for index in _clip_sets.size():
		if battle.soldiers[index].unit_type == Catalog.HUMAN_HEAVY_INFANTRY:
			_clip_sets[index] = _clip_sets[index].duplicate()
			_clip_sets[index].erase(Battle.State.DEAD)

func restart() -> void:
	for slot: HeavyDisplay in retirement_slots.values():
		_restore_surfaces(slot)
		slot.root.visible = slot.original_visibility
		slot.phase = Stage.LIVE
		slot.post_landing_s = 0.0
		slot.tier = 0
	super.restart()

func _sync_models(delta: float) -> void:
	super._sync_models(delta)
	if not retirement_ready or delta <= 0.0:
		return
	for index: int in retirement_slots:
		var slot: HeavyDisplay = retirement_slots[index]
		if slot.phase == Stage.RETIRED:
			continue
		var soldier := battle.soldiers[index]
		if soldier.state != Battle.State.DEAD or soldier.unit.is_alive():
			continue
		var owner_fall_s: float = Battle.DURATIONS[Battle.State.DEAD]
		if slot.phase == Stage.LIVE:
			# Refuse to invent a lifecycle for an old corpse injected mid-episode.
			if soldier.time <= delta + EPSILON and _players[index].assigned_animation == DEFEAT:
				slot.phase = Stage.FALL
				_players[index].seek(soldier.time, true)
			else:
				_hide_retired(slot)
				continue
		if slot.phase == Stage.FALL:
			if soldier.time < owner_fall_s:
				continue
			var player := _players[index]
			player.seek(player.get_animation(DEFEAT).length, true)
			player.pause()
			slot.phase = Stage.SETTLE
			continue
		slot.post_landing_s += delta
		if slot.post_landing_s + EPSILON >= SETTLE_SECONDS + TAPER_SECONDS:
			_hide_retired(slot)
		elif slot.post_landing_s + EPSILON >= SETTLE_SECONDS:
			slot.phase = Stage.TAPER
			var progress := clampf((slot.post_landing_s - SETTLE_SECONDS) / TAPER_SECONDS, 0.0, 1.0)
			var tier := mini(TAPER_DIVISIONS - 1, floori(progress * TAPER_DIVISIONS + EPSILON))
			if tier != slot.tier:
				slot.tier = tier
				for mesh in slot.surfaces:
					mesh.set_surface_override_material(0, retirement_palette[tier])

func _restore_surfaces(slot: HeavyDisplay) -> void:
	if slot.tier == 0:
		return
	for index in slot.surfaces.size():
		slot.surfaces[index].set_surface_override_material(0, slot.original_overrides[index])

func _hide_retired(slot: HeavyDisplay) -> void:
	slot.root.hide()
	_restore_surfaces(slot)
	slot.tier = 0
	slot.phase = Stage.RETIRED
