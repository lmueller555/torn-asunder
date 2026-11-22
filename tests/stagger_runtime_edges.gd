extends SceneTree

const B := preload("res://game/combat/infantry_skirmish.gd")
const Setup := preload("res://game/combat/skirmish_setup.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const View := preload("res://game/combat/infantry_skirmish_view.tscn")
const Mod := preload("res://game/combat/heavy_stagger_contact_modifier.gd")
const DT := 1.0/60.0
const FIRST_AMBER := B.PLATOON_SIZE
var _setup := Setup.new()
var _results:=0
var _world_updates:=0

class ForeignShoulder extends SkeletonModifier3D:
	var joint: int
	var desired: Vector3
	var callbacks := 0
	func _process_modification_with_delta(_delta: float)->void:
		var skeleton := get_skeleton()
		desired=skeleton.get_bone_pose_position(joint)+Vector3(.008,-.003,.002)
		skeleton.set_bone_pose_position(joint,desired)
		callbacks+=1

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var heavy := _setup.sides[0][0] as Setup.PlatoonBuild
	heavy.set_level(10)
	heavy.set_points(Unit.Damage.MELEE,9)
	assert(heavy.set_unit_type(Catalog.HUMAN_HEAVY_INFANTRY))
	var ordinary := _setup.sides[1][0] as Setup.PlatoonBuild
	ordinary.set_level(10)
	ordinary.set_points(Unit.Damage.MELEE,9)
	var view := View.instantiate()
	view.configure(_setup)
	root.add_child(view)
	view.set_physics_process(false)
	var hook:=view._stagger_contacts[0] as Mod
	assert(hook!=null and view._stagger_contacts[FIRST_AMBER]==null)
	var rig:=hook.rig
	var foreign_before:=ForeignShoulder.new()
	foreign_before.joint=rig.find_bone("Hand.L")
	rig.add_child(foreign_before)
	rig.move_child(foreign_before,hook.get_index())
	var foreign_after:=ForeignShoulder.new()
	foreign_after.joint=rig.find_bone("Hand.R")
	rig.add_child(foreign_after)
	rig.skeleton_updated.connect(func():
		if foreign_before.callbacks>0 and foreign_after.callbacks>0:
			assert(rig.get_bone_pose_position(foreign_before.joint).is_equal_approx(foreign_before.desired))
			assert(rig.get_bone_pose_position(foreign_after.joint).is_equal_approx(foreign_after.desired))
			_world_updates+=1)
	rig.modifier_callback_mode_process=Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	hook.profile_calls=true
	for state in [B.State.STAGGER,B.State.KNOCKDOWN,B.State.DEAD]:
		var seed:=_find_seed(state)
		assert(seed>=0)
		view.restart()
		var battle: B=view.battle
		var oracle:=B.new(8,_setup)
		var target:=battle.soldiers[0]
		_stage(battle,seed,state==B.State.DEAD)
		_stage(oracle,seed,state==B.State.DEAD)
		view._sync_models(0.0)
		var first:int=-1
		var second:int=-1
		var last_hp:=target.unit.hp
		for tick in range(1,25):
			var old_time:=target.time
			view._physics_process(DT)
			oracle.step(DT)
			assert(battle.hits==oracle.hits and battle.blocks==oracle.blocks)
			var ref:=oracle.soldiers[0]
			assert(target.state==ref.state and target.time==ref.time and target.position==ref.position and target.unit.hp==ref.unit.hp)
			if first<0 and battle.hits==1:
				first=tick
				assert(target.state==B.State.STAGGER and hook.active and target.unit.hp<last_hp)
				last_hp=target.unit.hp
			if second<0 and battle.hits==2:
				second=tick
				assert(target.state==state and target.unit.hp<last_hp)
				if state==B.State.STAGGER:
					assert(hook.has_episode and hook.active and target.time>old_time and hook.last_time==target.time)
				else:
					assert(not hook.active and not hook.has_episode)
			rig.advance(DT)
			await process_frame
			await process_frame
		assert(first>=1 and second>first and _world_updates>0 and foreign_before.active and foreign_after.active)
		print("Real ",B.State.keys()[state]," second contact: seed ",seed,", stagger tick ",first,", second tick ",second,"; follower parity/foreign stack retained.")
		_results+=1

	# Isolated visual fault injection (not asserted as solver events): a mismatched
	# rig, missing early episode, and both soles above plane must preserve stock output.
	var empty:=Skeleton3D.new()
	empty.add_bone("Root")
	var bad:=Mod.new()
	assert(not bad.configure(empty))
	bad.free()
	empty.free()
	view.restart()
	hook.prepare_tick(true,.22,DT)
	assert(hook.has_episode and not hook.active)
	hook.reset_episode()
	var actor: Node3D=view._models[0]
	var on_floor:=actor.position
	actor.position.y+=.065
	hook.prepare_tick(true,0.0,DT)
	assert(hook.has_episode and not hook.active)
	hook.reset_episode()
	actor.position=on_floor
	assert(not hook.active and not hook.has_episode)
	hook.prepare_tick(true,0.0,DT)
	assert(hook.active)
	var initial_fallbacks:=hook.fallback_calls
	actor.position.x+=1.9 # Synthetic unsupported view teleport, never a real battle rule.
	hook.prepare_tick(true,DT,DT)
	rig.advance(DT)
	await process_frame
	await process_frame
	assert(not hook.active and hook.fallback_calls==initial_fallbacks+1)
	assert(foreign_before.active and foreign_after.active)
	hook.reset_episode()
	actor.position=on_floor
	print("Safe source-pose fallback verified: missing rig, late entry, both feet airborne, and excessive reach. Both unrelated modifier nodes remain live over ",_world_updates," stack signals.")
	quit(0 if _results==3 else 1)

func _find_seed(expected: int)->int:
	for seed in range(100):
		var b:=B.new(8,_setup)
		_stage(b,seed,expected==B.State.DEAD)
		var got_first:=false
		for tick in range(1,25):
			b.step(DT)
			if b.hits==1 and b.soldiers[0].state==B.State.STAGGER:
				got_first=true
			if b.hits==2 and got_first and b.soldiers[0].state==expected:
				return seed
			if b.hits>=2:
				break
	return -1

func _stage(b: B, seed: int, lethal_second: bool)->void:
	var focus:=b.soldiers[0]
	var a0:=b.soldiers[FIRST_AMBER]
	var a1:=b.soldiers[FIRST_AMBER + 1]
	for s: B.Soldier in b.soldiers:
		if s.battle_index not in [0, FIRST_AMBER, FIRST_AMBER + 1]:
			s.unit.receive_damage(s.unit.hp)
			s.state=B.State.DEAD
			s.time=B.DURATIONS[B.State.DEAD]
	focus.position=Vector2(0,.55)
	focus.facing=Vector2.UP
	focus.target=FIRST_AMBER
	focus.state=B.State.IDLE
	focus.time=0.0
	focus.ready_in=10.0
	a0.position=Vector2(.36,-.44)
	a1.position=Vector2(-.36,-.47)
	for a:B.Soldier in [a0,a1]:
		a.facing=(focus.position-a.position).normalized()
		a.target=0
		a.state=B.State.ATTACK
		a.heavy=true
	a0.time=B.CONTACT-DT*.5
	a1.time=B.CONTACT-DT*8.5
	if lethal_second:
		var one_hit:=focus.unit.damage_from(a0.unit,a0.basic_attack)
		focus.unit.receive_damage(focus.unit.hp-1.55*one_hit)
	b._random.seed=seed
	b._index_bodies()
