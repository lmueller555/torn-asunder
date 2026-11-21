extends SceneTree

const Patrol := preload("res://game/battlefield/patrol_detection_policy.gd")
var _failures := 0


func _initialize() -> void:
	_bypass_and_discover()
	_break_contact()
	_leash_and_melee()
	_interceptor()
	_invalid_inputs()
	if _failures == 0:
		print("Patrol detection: cover bypass, visible acquisition, last-seen memory, leash, melee admission, and scripted interception passed.")
	quit(0 if _failures == 0 else 1)


func _bypass_and_discover() -> void:
	var agent := Patrol.new(35.0, 60.0, 3.0)
	var obs := Patrol.Observation.new()
	obs.authored_order = Patrol.AuthoredOrder.PATROL
	obs.candidates = [Patrol.Sighting.new(&"hero", Vector2(4, 1), false, true)]
	var out := agent.advance(12.0, obs)
	_check(out.intent == Patrol.Intent.PATROL and not out.has_destination and out.visible_contacts.is_empty(),
		"A friendly walking behind nearby cover does not interrupt a patrol, even if combat mistakenly reports close range.")
	obs.candidates[0].position = Vector2(36, 0)
	obs.candidates[0].unobstructed = true
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PATROL and out.visible_contacts.is_empty(), "A clear ray outside finite sight is not detection.")
	obs.candidates[0].position = Vector2(35, 0)
	obs.candidates[0].eligible = false
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PATROL and out.visible_contacts.is_empty(), "A dead/ineligible friendly does not appear at the sight boundary.")
	obs.candidates[0].eligible = true
	obs.candidates[0].melee_reachable = false
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PURSUE and out.contact_id == &"hero" and out.destination == Vector2(35, 0)
		and out.visible_contacts.size() == 1, "An eligible visible friendly at the sight boundary is acquired, not hit.")


func _break_contact() -> void:
	var agent := Patrol.new(25.0, 40.0, 2.0)
	var obs := Patrol.Observation.new()
	obs.authored_order = Patrol.AuthoredOrder.PATROL
	var hero := Patrol.Sighting.new(&"hero", Vector2(9, 3), true)
	obs.candidates = [hero]
	agent.advance(0.1, obs)
	hero.unobstructed = false
	hero.position = Vector2(16, 6)
	var out := agent.advance(0.8, obs)
	_check(out.intent == Patrol.Intent.INVESTIGATE and out.destination == Vector2(9, 3) and out.visible_contacts.is_empty(),
		"Broken sight leaves only the original last-seen point. Hidden movement is not live contact.")
	hero.position = Vector2(-22, 0)
	out = agent.advance(1.0, obs)
	_check(out.intent == Patrol.Intent.INVESTIGATE and out.destination == Vector2(9, 3),
		"Investigation never follows the target's undiscovered coordinates.")
	out = agent.advance(0.3, obs)
	_check(out.intent == Patrol.Intent.PATROL and not out.has_destination and out.contact_id == &"",
		"Once memory expires, the caller resumes the previously authored patrol without a target.")
	hero.unobstructed = true
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PURSUE and out.destination == Vector2(-22, 0),
		"A newly visible target can be rediscovered after returning to patrol.")


func _leash_and_melee() -> void:
	var agent := Patrol.new(30.0, 10.0, 3.0)
	var obs := Patrol.Observation.new()
	var outside := Patrol.Sighting.new(&"outside", Vector2(13, 0), true, true)
	var nearby := Patrol.Sighting.new(&"inside", Vector2(2, 0), true, false)
	obs.candidates = [outside]
	var out := agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.GUARD and out.visible_contacts.size() == 1,
		"A visible enemy beyond the leash is still a contact but not a pursuit or engagement.")
	obs.candidates.append(nearby)
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PURSUE and out.contact_id == &"inside" and out.visible_contacts.size() == 2,
		"Nearness cannot substitute for the separate combat reach observation.")
	nearby.melee_reachable = true
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.ENGAGE and out.contact_id == &"inside", "Combat may admit a reachable, already visible eligible target.")
	obs.patrol_position = Vector2(11, 0)
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.GUARD and out.contact_id == &"" and out.visible_contacts.size() == 2,
		"Leaving the authored patrol leash clears pursuit and memory without denying valid visibility.")
	obs.patrol_position = Vector2.ZERO
	nearby.unobstructed = false
	out = agent.advance(0.1, obs)
	_check(out.intent == Patrol.Intent.GUARD, "Returning within the leash does not revive discarded contact memory.")
	obs.candidates = [Patrol.Sighting.new(&"z", Vector2(-4, 0), true), Patrol.Sighting.new(&"a", Vector2(4, 0), true)]
	out = agent.advance(0.0, obs)
	_check(out.contact_id == &"a", "Equal-distance target ties are deterministic rather than collider iteration order.")


func _interceptor() -> void:
	var agent := Patrol.new(18.0, 21.0, 3.0)
	var obs := Patrol.Observation.new()
	obs.authored_order = Patrol.AuthoredOrder.PATROL
	var target := Patrol.Sighting.new(&"carrier", Vector2(50, 14), false)
	obs.candidates = [target]
	_check(agent.assign_interception(Vector2(39, -8)), "A scenario can explicitly issue an authored interception point.")
	var out := agent.advance(0.1, obs)
	_check(out.intent == Patrol.Intent.INTERCEPT and out.destination == Vector2(39, -8)
		and out.contact_id == &"" and out.visible_contacts.is_empty(),
		"The scripted march may leave the normal leash without gaining hidden knowledge.")
	target.position = Vector2(-81, 43)
	out = agent.advance(4.0, obs)
	_check(out.intent == Patrol.Intent.INTERCEPT and out.destination == Vector2(39, -8),
		"Elapsed time and hidden target movement do not change the authored interception destination.")
	obs.interception_arrived = true
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PATROL and not out.has_destination, "The movement adapter reports arrival and resumes normal observation.")
	obs.interception_arrived = false
	agent.assign_interception(Vector2(39, -8))
	target.position = Vector2(34, -6)
	target.unobstructed = true
	obs.patrol_position = Vector2(38, -8)
	obs.leash_anchor = Vector2(39, -8)
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.INTERCEPT and out.visible_contacts.size() == 1 and out.contact_id == &"",
		"Real sight is reported independently while the active authored march remains fixed.")
	obs.interception_arrived = true
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PURSUE and out.contact_id == &"carrier",
		"After arriving, a new post can acquire a genuinely visible target under ordinary rules.")
	target.unobstructed = false
	obs.interception_arrived = false
	agent.assign_interception(Vector2(39, -8))
	obs.interception_blocked = true
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PATROL and not out.has_destination, "A blocked authored route does not cause a warp or hidden chase.")
	obs.interception_blocked = false
	agent.assign_interception(Vector2(39, -8))
	agent.reset()
	out = agent.advance(0.0, obs)
	_check(out.intent == Patrol.Intent.PATROL, "Retry clears both memory and any outstanding scenario order.")


func _invalid_inputs() -> void:
	var agent := Patrol.new(INF, NAN, -1.0)
	var obs := Patrol.Observation.new()
	obs.candidates = [Patrol.Sighting.new(&"hero", Vector2.ZERO, true, true)]
	_check(agent.advance(NAN, obs).intent == Patrol.Intent.GUARD and not agent.assign_interception(Vector2(INF, 0)),
		"Invalid config/input cannot become unlimited sight, movement, or a non-finite scenario route.")


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
