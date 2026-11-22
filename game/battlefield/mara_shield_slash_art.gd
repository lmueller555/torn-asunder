extends RefCounted
## Greyhollow regular Shield Infantry presentation. Only the encounter can
## advance contact, damage, Battle Points, facing or formation position.

const Infantry := preload("res://game/battlefield/mara_infantry_attack.gd")
const Battle := preload("res://game/battlefield/command_battle.gd")
const CLIP := &"Sword Slash"
const READY := &"Idle"
const CONTACT := &"Shield Contact"
const NO_POSE := -1.0

var _source: Infantry
var _players: Array[AnimationPlayer]
var _support: Array[AnimationPlayer]
var _saved: Array[Dictionary] = []
var _slash_roots: Array[NodePath] = []
var _contact_position := 0.0
var _length := 0.0
var _seen_contact := 0
var _terminal_tail := 0.0
var _active := false


func configure(source: Infantry, players: Array[AnimationPlayer], group: Battle.Formation) -> bool:
	# The known stock art is all-or-nothing. Keep the existing presenter if a
	# future import is absent, incomplete or has lost its authored commit marker.
	if not source or group.members.is_empty() or players.size() != group.members.size():
		return false
	var front := INF
	for member in group.members:
		front = minf(front, member.offset.y)
	for index in range(players.size()):
		var player := players[index]
		if not is_equal_approx(group.members[index].offset.y, front):
			_support.append(player)
			continue
		if not player.has_animation(CLIP):
			return false
		var animation := player.get_animation(CLIP)
		if not animation.has_marker(CONTACT):
			return false
		var contact_position := animation.get_marker_time(CONTACT)
		if contact_position <= 0.0 or contact_position >= animation.length:
			return false
		if not _slash_roots.is_empty() and (not is_equal_approx(_length, animation.length) \
			or not is_equal_approx(_contact_position, contact_position)):
			return false
		var root_path := _root_position_track(animation)
		if root_path.is_empty():
			return false
		_players.append(player)
		_slash_roots.append(root_path)
		_saved.append({"root": player.root_motion_track, "process": player.callback_mode_process})
		_contact_position = contact_position
		_length = animation.length
	if _players.is_empty() or _support.is_empty():
		return false
	_source = source
	_seen_contact = _source.contact_serial
	return true


static func _root_position_track(animation: Animation) -> NodePath:
	for track in range(animation.get_track_count()):
		var path := animation.track_get_path(track)
		if animation.track_get_type(track) == Animation.TYPE_POSITION_3D \
			and path.get_concatenated_subnames() == "Root":
			return path
	return NodePath()


func sync(delta: float, group: Battle.Formation) -> bool:
	var committed := _source.contact_serial != _seen_contact
	_seen_contact = _source.contact_serial
	var pose := NO_POSE
	if group.can_receive_orders():
		if committed:
			pose = _contact_position
			# The resolver immediately Holds on a lethal hit. Finish only the
			# visual follow-through; do not extend or restart the combat order.
			if group.order == Battle.Order.HOLD:
				_terminal_tail = Infantry.RECOVERY_TIME
		elif group.order == Battle.Order.ATTACK:
			_terminal_tail = 0.0
			match _source.phase:
				Infantry.Phase.WINDUP:
					pose = _contact_position * _source.phase_progress()
				Infantry.Phase.RECOVERY:
					pose = lerpf(_contact_position, _length, _source.phase_progress())
		elif group.order == Battle.Order.HOLD and _terminal_tail > 0.0:
			_terminal_tail = maxf(_terminal_tail - delta, 0.0)
			pose = lerpf(_contact_position, _length, 1.0 - _terminal_tail / Infantry.RECOVERY_TIME)
	if pose < 0.0:
		cancel()
		return false
	# One visual fighting line represents the aggregate contact. Back
	# ranks retain the original ready pose and cannot signal a second cut.
	for player in _support:
		if player.current_animation != READY or not player.is_playing():
			player.play(READY, 0.10)
	for index in range(_players.size()):
		var player := _players[index]
		if not _active:
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.root_motion_track = _slash_roots[index]
			player.play(CLIP, 0.0)
		# Sample the pose once from authoritative phase time. Never run an
		# independent animation clock or fire animation events.
		player.seek(pose, true, true)
	_active = true
	return true


func cancel() -> bool:
	_terminal_tail = 0.0
	if not _active:
		return false
	_active = false
	for index in range(_players.size()):
		var player := _players[index]
		if not is_instance_valid(player):
			continue
		# Do not blend the outgoing slash's authored translation into Run/Idle.
		player.stop(true)
		player.root_motion_track = _saved[index].root
		player.callback_mode_process = _saved[index].process
	return true
