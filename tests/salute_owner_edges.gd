extends SceneTree
## Defensive ownership-only tests. Actual queue, winner, loss and draw are covered separately.
const B:=preload("res://game/combat/infantry_skirmish.gd")
const Setup:=preload("res://game/combat/skirmish_setup.gd")
const Catalog:=preload("res://game/combat/unit_catalog.gd")
const Unit:=preload("res://game/combat/combat_unit.gd")
const View:=preload("res://game/combat/infantry_skirmish_view.tscn")
const SALUTE:=&"Sword Cheer"
const READY:=&"Shield-Ready Idle"
const FIRST_AMBER := B.PLATOON_SIZE
func _initialize()->void:
	call_deferred("_run")
func _run()->void:
	var setup:=Setup.new()
	for side in [0,1]:
		setup.sides[side][0].set_level(10)
		setup.sides[side][0].set_points(Unit.Damage.MELEE,9)
		assert(setup.sides[side][0].set_unit_type(Catalog.HUMAN_HEAVY_INFANTRY))
	var v:=View.instantiate()
	v.configure(setup)
	root.add_child(v)
	v.set_physics_process(false)
	var b:B=v.battle
	var actor:=b.soldiers[0]
	var other:=b.soldiers[FIRST_AMBER]
	actor.state=B.State.CHEER
	other.state=B.State.CHEER
	actor.victory_cheers=B.VICTORY_CHEERS
	other.victory_cheers=B.VICTORY_CHEERS
	var player:AnimationPlayer=v._players[0]
	var opponent:AnimationPlayer=v._players[FIRST_AMBER]
	assert(player.has_animation(&"Death Fall") and player.assigned_animation == READY)
	v._sync_models(0)
	assert(player.assigned_animation==READY and opponent.assigned_animation==READY)
	b.winner=0
	v._sync_models(0)
	assert(player.assigned_animation==SALUTE and opponent.assigned_animation==READY)
	assert(not player.get_animation(SALUTE).loop_mode and is_equal_approx(player.get_animation(SALUTE).length,1.4))
	assert(not v._stagger_contacts[0].active and not v._stagger_contacts[FIRST_AMBER].active)
	actor.victory_cheers=0
	v._sync_models(0)
	assert(player.assigned_animation==READY)
	actor.victory_cheers=1
	b.winner=B.DRAW
	v._sync_models(0)
	assert(player.assigned_animation==READY and opponent.assigned_animation==READY)
	b.winner=0
	actor.unit.receive_damage(actor.unit.hp)
	v._sync_models(0)
	assert(player.assigned_animation==READY and not v._markers[0].visible)
	# An expired, explicitly injected corpse is not a genuine defeat episode.
	actor.state=B.State.DEAD
	actor.time=B.DURATIONS[B.State.DEAD]
	v._sync_models(1.0/60.0)
	assert(not v._models[0].visible and not v._markers[0].visible)
	print("Owner guards: live reserve with positive queue, wrong team, zero queue, draw, nonliving stale CHEER, and expired DEAD hide; real winner transition from same CHEER reroutes.")
	quit()
