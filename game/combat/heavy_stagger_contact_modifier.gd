extends SkeletonModifier3D
## Private presentation experiment. Uses only observed actor transforms; never mutates a Soldier.
## prepare_tick advances the plan with each actual physics position. The supported modifier
## callback consumes only the newest plan even when several solver ticks occur per draw.
## Godot applies and restores temporary poses as part of its modifier stack; no global overrides.

const EPS := 0.0001
const LEFT := 0
const RIGHT := 1
const MIN_LATERAL_SEPARATION := 0.245
const ENTRY_AIRBORNE := 0.024
const MAX_SAFE_REACH_ERROR := 0.045
const MAX_SAFE_ENTRY_FLOOR := 0.15
const SOLES := preload("res://game/combat/heavy_stagger_sole.gd")
# Actor-state seconds, hand off support exactly once per transition.
const WINDOWS := [
	[RIGHT, 0.067, 0.283, 0.110, 0.055],
	[LEFT, 0.283, 0.533, 0.115, 0.070],
	[RIGHT, 0.533, 0.767, 0.082, 0.015],
	[LEFT, 0.767, 0.900, 0.044, 0.0],
]

var rig: Skeleton3D
var chains: Array[PackedInt32Array] = []
var ready_foot: Array[Transform3D] = []
var ready_toe: Array[Transform3D] = []
var locked_w: Array[Transform3D] = []
var locked_toe: Array[Transform3D] = []
var last_origin: Vector3
var v: Vector3
var last_time := 0.0
var has_episode := false
var _suspended := false
var enabled_for_rig := false
var profile_calls := false
var callback_calls := 0
var applied_calls := 0
var fallback_calls := 0
var callback_usec := 0
var previous_window := -1
var reverse_sequence := false
var selected_path := false
var lateral_path := false
var lift_start: Transform3D
var lift_start_toe: Transform3D
var airborne_entry := -1
var intended: Array[Transform3D] = []
var intended_toe: Array[Transform3D] = []
var current_swing := -1
var current_arc := 0.0
var current_window := -1
var reachable_corrections := [0.0, 0.0]

func configure(skeleton: Skeleton3D) -> bool:
	active = false
	rig = skeleton
	if rig == null:
		return false
	for side: String in ["L","R"]:
		var chain := PackedInt32Array()
		for part: String in ["Thigh", "Shin", "Foot", "Toe"]:
			var bone := rig.find_bone(part + "." + side)
			if bone == -1:
				return false
			if not chain.is_empty() and rig.get_bone_parent(bone) != chain[-1]:
				return false
			chain.append(bone)
		if rig.get_bone_parent(chain[0]) < 0:
			return false
		var foot := rig.get_bone_global_pose(chain[2])
		var toe := rig.get_bone_global_pose(chain[3])
		if not foot.is_finite() or not toe.is_finite() or absf(foot.basis.determinant()) < EPS:
			return false
		chains.append(chain)
		ready_foot.append(foot)
		ready_toe.append(foot.affine_inverse() * toe)
		locked_w.append(Transform3D.IDENTITY)
		locked_toe.append(Transform3D.IDENTITY)
		intended.append(Transform3D.IDENTITY)
		intended_toe.append(Transform3D.IDENTITY)
	enabled_for_rig = true
	return true

func reset_episode() -> void:
	has_episode = false
	_suspended = false
	active = false

func _use_source_pose() -> void:
	_suspended = true
	active = false
	if profile_calls:
		fallback_calls += 1

func prepare_tick(wants_stagger: bool, elapsed: float, dt: float) -> void:
	if not wants_stagger or not enabled_for_rig:
		if has_episode:
			reset_episode()
		return
	if not is_finite(elapsed) or not is_finite(dt) or elapsed < 0.0 or dt < 0.0 or not rig.global_transform.is_finite():
		has_episode = true
		_use_source_pose()
		return
	var new_episode := not has_episode or elapsed + EPS < last_time
	if new_episode:
		has_episode = true
		_suspended = false
		if elapsed > 0.05:
			# Attached late; never synthesize a lost first contact/history.
			_use_source_pose()
			last_time = elapsed
			return
	if _suspended:
		return
	if not new_episode and elapsed <= last_time + EPS:
		return
	var model_transform := rig.global_transform
	var actor_origin := model_transform.origin
	if new_episode:
		var entry_sole := Vector2(_sole_floor(LEFT, model_transform),_sole_floor(RIGHT, model_transform))
		if not entry_sole.is_finite() or minf(entry_sole.x, entry_sole.y) > ENTRY_AIRBORNE \
			or minf(entry_sole.x, entry_sole.y) < -MAX_SAFE_ENTRY_FLOOR:
			_use_source_pose()
			last_time=elapsed
			return
		active = true
		previous_window = -1
		reverse_sequence=false
		selected_path=false
		lateral_path=false
		v = Vector3.ZERO
		last_origin = actor_origin
		airborne_entry = -1
		if maxf(entry_sole.x,entry_sole.y)>ENTRY_AIRBORNE:
			airborne_entry = LEFT if entry_sole.x>entry_sole.y else RIGHT
			# Already in flight: continue this foot, start its swing immediately.
			reverse_sequence = airborne_entry==LEFT
			selected_path=true
		for side in [LEFT,RIGHT]:
			var raw_skeleton := rig.get_bone_global_pose(chains[side][2])
			if not raw_skeleton.is_finite() or absf(raw_skeleton.basis.determinant())<EPS:
				_use_source_pose()
				last_time=elapsed
				return
			var raw := model_transform * raw_skeleton
			var local_toe := raw_skeleton.affine_inverse() * rig.get_bone_global_pose(chains[side][3])
			if side!=airborne_entry:
				# Lock actually loaded heel/toe contact without flattening an existing toe roll.
				raw.origin.y -= entry_sole[side]
			locked_w[side] = raw
			locked_toe[side] = local_toe
	else:
		var step := actor_origin - last_origin
		step.y = 0.0
		v = v.lerp(step / maxf(EPS,dt),0.68)
	last_origin=actor_origin
	last_time=elapsed
	current_swing=-1
	current_arc=0.0
	current_window=-1
	for win in range(WINDOWS.size()):
		var window: Array = WINDOWS[win]
		if elapsed + EPS >= _window_start(win) and elapsed < float(window[2]) + EPS:
			current_window=win
			if not selected_path:
				# Choose the leading boot from actual initial displacement, not from an
				# assumed hit angle. A lateral catch must not cross the planted boot.
				var lateral := v.normalized().dot(model_transform.basis.x.normalized())
				lateral_path = absf(lateral) > 0.45
				reverse_sequence = lateral > 0.45
				selected_path = true
			current_swing=_side_for(window)
	if previous_window!=current_window:
		if previous_window >= 0:
			# Resolve the preceding support at its authored contact using the present anchor,
			# not a forecast of the nominal .78 m knockback or a transform override on the actor.
			var landed := _side_for(WINDOWS[previous_window])
			locked_w[landed] = _target(model_transform,WINDOWS[previous_window])
			locked_toe[landed] = ready_toe[landed]
		if current_window >= 0:
			lift_start = locked_w[current_swing]
			lift_start_toe = locked_toe[current_swing]
	previous_window=current_window
	for side in [LEFT,RIGHT]:
		var goal:=locked_w[side]
		var toe:=locked_toe[side]
		if side==current_swing:
			var window: Array = WINDOWS[current_window]
			var u := clampf(inverse_lerp(_window_start(current_window),float(window[2]),elapsed),0,1)
			var t := smoothstep(0.0,1.0,u)
			var aim := _target(model_transform,window)
			var bias := sin(PI*u)
			var gap := (aim.origin-lift_start.origin)
			gap.y=0.0
			var effort := smoothstep(.011,.115,gap.length())
			current_arc = pow(bias,1.35) * float(window[3]) * effort
			goal.origin = lift_start.origin.lerp(aim.origin,t) + Vector3.UP*current_arc
			if t>EPS:
				var q := lift_start.basis.get_rotation_quaternion().slerp(aim.basis.get_rotation_quaternion(),t)
				goal.basis = Basis(q).scaled_local(lift_start.basis.get_scale().lerp(aim.basis.get_scale(),t))
			toe = lift_start_toe.interpolate_with(ready_toe[side],t)
		intended[side]=goal
		intended_toe[side]=toe

func _sole_floor(side: int, actor: Transform3D) -> float:
	var track := chains[side]
	var foot := actor * rig.get_bone_global_pose(track[2])
	var toe := actor * rig.get_bone_global_pose(track[3])
	var low := INF
	var samples := SOLES.L if side==LEFT else SOLES.R
	for sample: Array in samples:
		var foot_local: Vector3 = sample[0]
		var toe_local: Vector3 = sample[1]
		var foot_weight: float = sample[2]
		low=minf(low,(foot*foot_local).y*foot_weight+(toe*toe_local).y*(1.0-foot_weight))
	return low

func _process_modification_with_delta(_delta: float) -> void:
	if not has_episode or _suspended or rig != get_skeleton():
		return
	var start := Time.get_ticks_usec() if profile_calls else 0
	if profile_calls:
		callback_calls += 1
	var space := rig.global_transform
	if not space.is_finite() or absf(space.basis.determinant())<EPS:
		_use_source_pose()
		return
	var inv := space.affine_inverse()
	# Solve both sides before any pose writes. Invalid or incompatible inputs leave
	# the whole original source pose, including modifications from other owners.
	var left := _solve(LEFT,inv * intended[LEFT],intended_toe[LEFT])
	var right := _solve(RIGHT,inv * intended[RIGHT],intended_toe[RIGHT])
	if left.is_empty() or right.is_empty():
		_use_source_pose()
		return
	_write(LEFT,left)
	_write(RIGHT,right)
	if profile_calls:
		applied_calls+=1
		callback_usec+=Time.get_ticks_usec()-start

func _write(side: int, joints: Array[Transform3D]) -> void:
	for i in range(joints.size()):
		var pose := joints[i]
		var bone := chains[side][i]
		rig.set_bone_pose_position(bone,pose.origin)
		rig.set_bone_pose_rotation(bone,pose.basis.get_rotation_quaternion())
		rig.set_bone_pose_scale(bone,pose.basis.get_scale())

func _window_start(index:int)->float:
	if index==0 and airborne_entry>=0:
		return 0.0
	return float(WINDOWS[index][1])

func _side_for(window: Array) -> int:
	var side := int(window[0])
	return 1-side if reverse_sequence else side

func _target(actor: Transform3D, window: Array) -> Transform3D:
	var side := _side_for(window)
	var target := actor*ready_foot[side]
	# Measured, bounded lead only. Zero for the final regrouping step.
	var lateral_leading_step := lateral_path and window == WINDOWS[0]
	var lead_seconds := .130 if lateral_leading_step else float(window[4])
	var cap := .184 if lateral_leading_step else .130
	var lead := v * lead_seconds
	var magnitude := lead.length()
	if magnitude>cap:
		lead = lead * (cap/magnitude)
	target.origin += lead
	var foot_side := actor.basis.x.normalized() * (1.0 if side==LEFT else -1.0)
	var clearance := (target.origin - locked_w[1-side].origin).dot(foot_side)
	if clearance < MIN_LATERAL_SEPARATION:
		target.origin += foot_side * (MIN_LATERAL_SEPARATION-clearance)
	return target

func _solve(side: int, target: Transform3D, relative_toe: Transform3D) -> Array[Transform3D]:
	var track := chains[side]
	var thigh := rig.get_bone_global_pose(track[0])
	var shin := rig.get_bone_global_pose(track[1])
	var raw_foot := rig.get_bone_global_pose(track[2])
	var a := shin.origin.distance_to(thigh.origin)
	var b := raw_foot.origin.distance_to(shin.origin)
	var aim := target.origin-thigh.origin
	var length := aim.length()
	if not target.is_finite() or not is_finite(length) or length < EPS or minf(a,b) < EPS:
		return []
	var forward := aim/length
	var solved_len := clampf(length,absf(a-b)+EPS,a+b-EPS)
	var along := (a*a-b*b+solved_len*solved_len)/(2.0*solved_len)
	var rise := sqrt(maxf(0.0,a*a-along*along))
	var raw_bend := shin.origin-thigh.origin
	var pole := (raw_bend-forward*raw_bend.dot(forward)).normalized()
	if pole.length_squared()<EPS: pole=Vector3.FORWARD
	var knee := thigh.origin+forward*along+pole*rise
	var ankle := thigh.origin+forward*solved_len
	reachable_corrections[side]=absf(length-solved_len)
	if reachable_corrections[side] > MAX_SAFE_REACH_ERROR:
		return []
	thigh.basis = Basis(Quaternion(shin.origin-thigh.origin,knee-thigh.origin)) * thigh.basis
	shin.basis = Basis(Quaternion(raw_foot.origin-shin.origin,ankle-knee)) * shin.basis
	shin.origin=knee
	target.origin=ankle
	var parent := rig.get_bone_global_pose(rig.get_bone_parent(track[0]))
	if not parent.is_finite() or absf(parent.basis.determinant())<EPS:
		return []
	# Build each local pose from the final desired parent directly. Do not mutate
	# another bone's state or repeatedly force a whole-skeleton refresh.
	return [
		parent.affine_inverse()*thigh,
		thigh.affine_inverse()*shin,
		shin.affine_inverse()*target,
		relative_toe,
	]
