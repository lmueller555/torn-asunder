extends SceneTree
const Setup := preload("res://game/combat/skirmish_setup.gd")
const Battle := preload("res://game/combat/infantry_skirmish.gd")
const Catalog := preload("res://game/combat/unit_catalog.gd")
const Unit := preload("res://game/combat/combat_unit.gd")
const StockView := preload("res://game/combat/infantry_skirmish_view.tscn")
const TICK:=1.0/60.0
const FOCUS: Array[int]=[Battle.State.KNOCKDOWN,Battle.State.DOWN,Battle.State.GET_UP]
func _initialize() -> void:
	call_deferred("_test")
func _test() -> void:
	var setup := Setup.new()
	var seats:=int(OS.get_environment("HEAVY_FALL_PLATOONS"))
	seats = 1 if seats==0 else seats
	assert(seats in [1,4])
	var behavior_ticks:=0
	var complete_hold_edges:=0
	var check_restart:=false
	for side in [0,1]:
		setup.set_count(side,seats)
		for build: Setup.PlatoonBuild in setup.sides[side]:
			build.set_level(10)
			build.set_points(Unit.Damage.MELEE,9)
			assert(build.set_unit_type(Catalog.HUMAN_HEAVY_INFANTRY))
	var oracle := Battle.new(8,setup)
	var view := StockView.instantiate()
	view.configure(setup)
	root.add_child(view)
	view.set_physics_process(false)
	assert(view.battle.soldiers.size()==64*seats)
	for hook in view._stagger_contacts:
		assert(hook!=null)
	var terminal: Array[Transform3D]=_authored_terminal()
	var last: Dictionary[int,int]={}
	var entered: Dictionary[int,int]={}
	var states: Dictionary={}
	var final_ready := 0
	var holds: Dictionary[int,Array]={}
	var total_hold_ticks := 0
	for tick in range(60*10):
		oracle.step(TICK)
		view._physics_process(TICK)
		if oracle.hits != view.battle.hits or oracle.blocks != view.battle.blocks:
			fail("Contact counter mismatch")
			return
		for i in range(oracle.soldiers.size()):
			var native: Battle.Soldier=view.battle.soldiers[i]
			var expected:=oracle.soldiers[i]
			var model:Node3D=view._models[i]
			if native.state != expected.state or native.time != expected.time or native.facing != expected.facing or native.position != expected.position or native.unit.hp != expected.unit.hp or model.position != Vector3(native.position.x,0,native.position.y):
				fail("Combat or model anchor changed at %d/%d"%[tick,i])
				return
			var before:int=last.get(i,-1)
			var player:AnimationPlayer=view._players[i]
			var contact:SkeletonModifier3D=view._stagger_contacts[i]
			if contact.active:
				if native.state!=Battle.State.STAGGER or player.assigned_animation!=&"Hit Stagger":
					fail("Shipped catch ran outside open-Hit Stagger")
					return
				behavior_ticks+=1
			if native.state in FOCUS:
				if contact.active or contact.has_episode:
					fail("A stale approved boot catch overlapped the fall pair")
					return
				if before==Battle.State.DOWN and native.state==Battle.State.GET_UP:
					if tick-int(entered[i])!=ceili(float(Battle.DURATIONS[Battle.State.DOWN])/TICK):
						fail("The held terminal dwell no longer matches existing 60 Hz DOWN")
						return
					complete_hold_edges+=1
				if before!=native.state:
					states[native.state]=states.get(native.state,0)+1
					entered[i]=tick
				if player.assigned_animation != (&"Get Up" if native.state==Battle.State.GET_UP else &"Backward Knockdown"):
					fail("Wrong live clip on %d/%d (%s)"%[tick,i,Battle.State.keys()[native.state]])
					return
				var skel:=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
				if skel.get_bone_pose_position(skel.find_bone("Root")).length()>0.00003:
					fail("Model root double displacement")
					return
				if native.state==Battle.State.DOWN:
					if absf(player.current_animation_position-player.get_animation(&"Backward Knockdown").length)>.00005:
						fail("The exact final fall key is not held")
						return
					var here:Array[Transform3D]=[]
					for bone in range(skel.get_bone_count()):
						here.append(skel.get_bone_global_pose(bone))
					if before!=Battle.State.DOWN:
						holds[i]=here
					var saved:Array=holds[i]
					for bone in range(skel.get_bone_count()):
						if not here[bone].is_equal_approx(saved[bone]) or not here[bone].is_equal_approx(terminal[bone]):
							fail("Down floor pose changed for %d/%d, bone %s"%[tick,i,skel.get_bone_name(bone)])
							return
					total_hold_ticks+=1
			if before==Battle.State.GET_UP and native.state==Battle.State.IDLE:
				final_ready+=1
				if player.assigned_animation!=&"Shield-Ready Idle":
					fail("Get Up failed to hand off to Heavy ready")
					return
			last[i]=native.state
	if states.size()!=3 or final_ready == 0 or total_hold_ticks < 15:
		fail("No complete real fall chain: " + str(states))
		return
	assert(complete_hold_edges>0 and behavior_ticks>0)
	view.restart()
	for i in range(view.battle.soldiers.size()):
		var avatar: Battle.Soldier=view.battle.soldiers[i]
		var anim: AnimationPlayer=view._players[i]
		var contact: SkeletonModifier3D=view._stagger_contacts[i]
		assert(avatar.state==Battle.State.IDLE and anim.assigned_animation==&"Shield-Ready Idle" and not contact.active and not contact.has_episode)
	check_restart=true
	print("Unforced native ",32*seats,"+",32*seats," Heavy mirror seed 8: ",states,". Held actor-ticks=",total_hold_ticks,", exact DOWN-to-GET_UP edges=",complete_hold_edges,", ready handoffs=",final_ready,", #306 open-hit catch actor-ticks=",behavior_ticks,", restart=",check_restart,"; original sim state/time/HP/position/contact parity over all 600 ticks.")
	quit()
func _authored_terminal() -> Array[Transform3D]:
	var model := preload("res://assets/models/human_heavy_infantry.glb").instantiate()
	root.add_child(model)
	var player:=model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	var skel:=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	player.play(&"Backward Knockdown",0.0)
	player.advance(0.0)
	player.seek(1.15,true)
	skel.force_update_all_bone_transforms()
	var out: Array[Transform3D]=[]
	for joint in range(skel.get_bone_count()):
		out.append(skel.get_bone_global_pose(joint))
	model.queue_free()
	return out

func fail(note:String) -> void:
	push_error(note)
	quit(1)
