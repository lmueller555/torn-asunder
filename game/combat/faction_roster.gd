extends RefCounted
## Metadata and stat-gate queries, not equipment, unlocked saves or battlefield AI.

const Unit := preload("res://game/combat/combat_unit.gd")
const Platoon := preload("res://game/combat/platoon.gd")

const HUMANS := &"humans"
const ORCS := &"orcs"
const ELVES := &"elves"
const DRUIDS := &"druids"
const DRYADS := &"dryads"
const UNDEAD := &"undead"
const FACTIONS := [HUMANS, ORCS, ELVES, DRUIDS, DRYADS, UNDEAD]

const RANGED := &"ranged"
const MELEE := &"melee"
const ELEMENTALS := &"elementals"
const CASTERS := &"casters"
const RIDING := &"riding"
const ANTI_RIDING := &"anti_riding"
const FLYING := &"flying"
const SIEGE := &"siege"
const ELITE_SUPPORT := &"elite_support"
const ENGINEERING := &"engineering"

const LABELS := {
	RANGED: "Ranged",
	MELEE: "Melee",
	ELEMENTALS: "Elementals",
	CASTERS: "Casters",
	RIDING: "Riding",
	ANTI_RIDING: "Anti-riding",
	FLYING: "Flying",
	SIEGE: "Siege",
	ELITE_SUPPORT: "Elite Support",
}

var _units: Dictionary[StringName, Dictionary] = {}
var _advances: Array[Dictionary] = []


## Elite Support is independent standing, never a replacement for the unit's
## battlefield function. Engineering is an optional secondary capability.
func add_unit(id: StringName, faction: StringName, primary_family: StringName,
		secondary_tags: Array[StringName] = [], elite_support := false, display_name := "") -> bool:
	if id == &"" or _units.has(id) or faction not in FACTIONS or not _is_family(primary_family):
		return false
	var seen: Array[StringName] = [primary_family]
	for tag in secondary_tags:
		if tag in seen or (tag != ENGINEERING and not _is_family(tag)):
			return false
		seen.append(tag)
	_units[id] = {
		"id": id,
		"faction": faction,
		"primary_family": primary_family,
		"secondary_tags": secondary_tags.duplicate(),
		"elite_support": elite_support,
	}
	if not display_name.strip_edges().is_empty():
		_units[id]["display_name"] = display_name.strip_edges()
	return true


func unit(id: StringName) -> Dictionary:
	return _units.get(id, {}).duplicate(true)


func units_for_faction(faction: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _units:
		if _units[id].faction == faction:
			ids.append(id)
	return ids


func has_label(id: StringName, role_or_tag: StringName) -> bool:
	var row: Dictionary = _units.get(id, {})
	if row.is_empty():
		return false
	if role_or_tag == ELITE_SUPPORT:
		return row.elite_support
	return row.primary_family == role_or_tag or role_or_tag in row.secondary_tags


## Advance only through explicit same-faction links; every edge has a stat gate.
## Multiple edges may start from a unit and not every unit needs an advancement.
func add_advance(source: StringName, target: StringName, ratings: Dictionary, training: Dictionary = {}) -> bool:
	if not _units.has(source) or not _units.has(target) or source == target \
		or _units[source].faction != _units[target].faction or (ratings.is_empty() and training.is_empty()) \
		or not _gates_valid(ratings, Unit.Damage.values(), Unit.MIN_RATING, Unit.MAX_RATING) \
		or not _gates_valid(training, Platoon.Skill.values(), 1, Platoon.MAX_RANK) \
		or not _edge(source, target).is_empty() or _has_path(target, source):
		return false
	_advances.append({"source": source, "target": target, "ratings": ratings.duplicate(), "training": training.duplicate()})
	return true


func advancement(source: StringName, target: StringName) -> Dictionary:
	return _edge(source, target).duplicate(true)


func can_advance(source: StringName, target: StringName, read_rating := Callable(), read_training := Callable()) -> bool:
	var rule := _edge(source, target)
	return not rule.is_empty() and _qualifies(rule, read_rating, read_training)


func eligible_advances(source: StringName, read_rating := Callable(), read_training := Callable()) -> Array[StringName]:
	var targets: Array[StringName] = []
	for edge in _advances:
		if edge.source == source and _qualifies(edge, read_rating, read_training):
			targets.append(edge.target)
	return targets


## Inspect direct branches for a known unit in the supplied faction. Each
## ratings/training entry is keyed by its own enum (even if the integers overlap)
## and reports {current, minimum, missing}. Unavailable/invalid reads are null,
## never zero; one unknown requirement keeps the branch ineligible.
func inspect_advances(source: StringName, faction: StringName,
		read_rating := Callable(), read_training := Callable()) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not _units.has(source) or _units[source].faction != faction:
		return rows
	var rating_values := {}
	var training_values := {}
	for edge in _advances:
		if edge.source != source:
			continue
		var ratings := _inspect_gates(edge.ratings, read_rating, Unit.MIN_RATING, Unit.MAX_RATING, rating_values)
		var training := _inspect_gates(edge.training, read_training, 0, Platoon.MAX_RANK, training_values)
		rows.append({
			"target": edge.target,
			"eligible": _no_missing(ratings) and _no_missing(training),
			"ratings": ratings,
			"training": training,
		})
	return rows


func _edge(source: StringName, target: StringName) -> Dictionary:
	for edge in _advances:
		if edge.source == source and edge.target == target:
			return edge
	return {}


func _has_path(source: StringName, target: StringName) -> bool:
	var pending: Array[StringName] = [source]
	var visited: Dictionary[StringName, bool] = {}
	while not pending.is_empty():
		var here: StringName = pending.pop_back()
		if visited.has(here):
			continue
		visited[here] = true
		if here == target:
			return true
		for edge in _advances:
			if edge.source == here:
				pending.append(edge.target)
	return false


static func _is_family(label: StringName) -> bool:
	return label != ELITE_SUPPORT and LABELS.has(label)


static func _gates_valid(gates: Dictionary, valid: Array, minimum: int, maximum: int) -> bool:
	for stat in gates:
		if typeof(stat) != TYPE_INT or stat not in valid:
			return false
		var required: Variant = gates[stat]
		if typeof(required) != TYPE_INT or required < minimum or required > maximum:
			return false
	return true


static func _qualifies(edge: Dictionary, read_rating: Callable, read_training: Callable) -> bool:
	return _meets(edge.ratings, read_rating, Unit.MIN_RATING, Unit.MAX_RATING) \
		and _meets(edge.training, read_training, 0, Platoon.MAX_RANK)


static func _meets(gates: Dictionary, reader: Callable, floor_value: int, maximum: int) -> bool:
	for stat: int in gates:
		var actual: Variant = _read_stat(reader, stat, floor_value, maximum)
		if actual == null or actual < gates[stat]:
			return false
	return true


static func _inspect_gates(gates: Dictionary, reader: Callable, floor_value: int, maximum: int, cache: Dictionary) -> Dictionary:
	var report := {}
	for stat: int in gates:
		# All sibling branches in one inspection share a stat snapshot.
		if not cache.has(stat):
			cache[stat] = _read_stat(reader, stat, floor_value, maximum)
		var actual: Variant = cache[stat]
		var minimum: int = gates[stat]
		report[stat] = {
			"current": actual,
			"minimum": minimum,
			"missing": null if actual == null else maxi(minimum - int(actual), 0),
		}
	return report


static func _no_missing(report: Dictionary) -> bool:
	for requirement: Dictionary in report.values():
		if requirement.missing != 0:
			return false
	return true


static func _read_stat(reader: Callable, stat: int, floor_value: int, maximum: int) -> Variant:
	if not reader.is_valid():
		return null
	var actual: Variant = reader.call(stat)
	return actual if typeof(actual) == TYPE_INT and actual >= floor_value and actual <= maximum else null
