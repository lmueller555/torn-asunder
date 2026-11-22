extends SceneTree

const Battle := preload("res://game/battlefield/command_battle.gd")
const Size := preload("res://game/combat/platoon_size.gd")
const Quay := preload("res://game/battlefield/mara_moonwash_quay.gd")
const SCENES := {
	"mara_greyhollow_rescue_campaign": [31, 12],
	"mara_grain_crossing_campaign": [31, 12],
	"mara_moonwash_playtest": [31, 31],
	"raska_well_road_playtest": [31, 12],
	"raska_mine_witness": [31, 31],
	"raska_spanwater": [31, 12],
	"ilyra_coast_survey_campaign": [31],
	"ilyra_moonwash_rescue_campaign": [12, 31],
	"ilyra_spanwater_playtest": [31, 12],
	"sova_mine_evacuation_campaign": [31, 31],
	"sova_public_record_playtest": [31, 31],
	"sova_vault_return_playtest": [31, 31],
	"neris_failing_grove_playtest": [31, 31],
	"neris_greyhollow_campaign": [31, 31],
	"neris_spanwater_playtest": [31, 31],
	"neris_cairnspine_survey": [],
	"sereth_cut_playtest": [31, 31],
	"sereth_pass_writ_playtest": [31, 31],
	"sereth_no_proxy_playtest": [31, 31],
}
var _failed := false

func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, label: String) -> void:
	if not ok:
		_failed = true
		printerr(label)


func _run() -> void:
	_check_column_reverse()
	for key: String in SCENES:
		var scene := load("res://game/battlefield/" + key + ".tscn") as PackedScene
		var mission: Node3D = scene.instantiate()
		root.add_child(mission)
		mission.set_physics_process(false)
		await physics_frame
		await physics_frame
		mission._sync_view()
		var expected: Array = SCENES[key]
		_expect(mission.battle.formations.size() == expected.size(), key + ": authored slots")
		for i in range(expected.size()):
			var group: Battle.Formation = mission.battle.formations[i]
			var anchors: Array = mission._formation_members[i]
			_expect(group.members.size() == expected[i] and anchors.size() == expected[i], key + ": indexed roster count")
			if group.members.size() != expected[i] or anchors.size() != expected[i]:
				continue
			var unique := {}
			var files := {}
			var ranks := {}
			for slot in group.members:
				var feet: Vector3 = anchors[slot.index].global_position
				var real: Vector3 = mission.to_global(mission._ground(group.member_position(slot)))
				_expect(feet.distance_to(real) < 0.025, key + ": visible feet attached to authoritative slot")
				_expect(not unique.has(slot.offset), key + ": unique body positions")
				unique[slot.offset] = true
				if not slot.is_leader:
					files[slot.offset.x] = true
					ranks[slot.offset.y] = true
			var xs := files.keys()
			var zs := ranks.keys()
			xs.sort()
			zs.sort()
			for slot_index in range(1, xs.size()):
				_expect(float(xs[slot_index])-float(xs[slot_index-1]) >= 0.49, key + ": adjacent body width")
			for slot_index in range(1, zs.size()):
				_expect(float(zs[slot_index])-float(zs[slot_index-1]) >= 0.56, key + ": adjacent body and kit length")
			var melee: bool = expected[i] == Size.PLATOON_WITH_LEADER
			_expect(files.size() == (5 if melee else 4) and ranks.size() == (6 if melee else 3), key + ": explicit formation grid")
			_expect((group.leader != null and group.leader.index == Size.REGULAR_MELEE and group.leader.is_leader
				and is_zero_approx(group.leader.offset.x) and group.leader.offset.y < float(zs[0]))
				if melee else group.leader == null, key + ": unique fighting leader centered ahead of non-hero regulars")
			_expect(group.role == Battle.FormationRole.REGULAR_MELEE if expected[i] == Size.PLATOON_WITH_LEADER
				else group.role in [Battle.FormationRole.RANGED, Battle.FormationRole.SUPPORT], key + ": explicit role")
			var legal := group.footprint_fits(group.position)
			print(key, " slot=", i, " members=", group.members.size(), " files=", files.size(), " spawn_hull=", legal)
			_expect(legal, key + ": full authored spawn hull")
		if key == "mara_moonwash_playtest":
			var group: Battle.Formation = mission.battle.formations[0]
			var id := group.members[0].get_instance_id()
			# Put the real group at the authored exit in this isolated check; the
			# stock scenario test independently drives the real paths to it.
			var point: Vector3 = mission._exit.global_position
			group.position = Vector2(point.x, point.z)
			var first: Quay.PlatoonObservation = mission._platoon_observation(Quay.Platoon.FIRST)
			var later: Quay.PlatoonObservation = mission._platoon_observation(Quay.Platoon.FIRST)
			_expect(first.living_members.size() == Size.PLATOON_WITH_LEADER and first.crossed_upper_exit.size() == Size.PLATOON_WITH_LEADER
				and later.living_members.size() == Size.PLATOON_WITH_LEADER and later.crossed_upper_exit.is_empty(),
				key + ": every indexed foot crosses once; not a centroid or mesh-visibility proxy")
			mission.restart_mission()
			_expect(mission.battle.formations[0].members[0].get_instance_id() != id
				and not mission.battle.formations[0].members[0].crossed
				and mission._formation_members[0][0].visible, key + ": retry resets real crossing/visible slots")
		mission.queue_free()
		await process_frame
	print("AUTHORED 31-MEMBER FOOTPRINTS ", "HOLD" if _failed else "PASS")
	quit(1 if _failed else 0)


func _check_column_reverse() -> void:
	var column := Battle.Formation.new("Fixture", Vector2.ZERO)
	column.configure_role(Battle.FormationRole.REGULAR_MELEE, 4, Vector2(0.56, 0.57), 0.23)
	var member := column.members[0]
	var first_foot := column.member_position(member)
	column.member_footprint_check = func(group: Battle.Formation, _point: Vector2) -> bool:
		return group.heading == Vector2.UP
	column.destination = Vector2(0.0, 5.0)
	column.order = Battle.Order.MOVE
	column.advance(0.1, Callable())
	_expect(column.order == Battle.Order.MOVE and column.heading == Vector2.UP
		and column.members[0] == member and (column.member_position(member)-first_foot).is_equal_approx(Vector2(0, 0.3)),
		"Narrow column can back out with fixed body spacing and the same indexed members")
	column.member_footprint_check = func(_group: Battle.Formation, _point: Vector2) -> bool: return false
	var past := column.position
	column.advance(0.1, Callable())
	_expect(column.position == past and column.order == Battle.Order.BLOCKED,
		"An invalid footprint in every facing cannot move or teleport")
