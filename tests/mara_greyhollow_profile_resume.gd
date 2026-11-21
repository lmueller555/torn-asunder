extends SceneTree

const Profile := preload("res://game/profile_store.gd")


func _initialize() -> void:
	var path := "user://greyhollow-resume-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var passed := _verify(path)
	for f in [path, path + ".tmp"]:
		if FileAccess.file_exists(f) or DirAccess.dir_exists_absolute(f):
			DirAccess.remove_absolute(f)
	if passed:
		print("Greyhollow progress: authentic rescue, atomic writes, interruption and acknowledgement, and legacy isolation passed.")
	quit(0 if passed else 1)


func _verify(path: String) -> bool:
	var profile := Profile.new(path)
	if profile.greyhollow_reveal_pending() or profile.record_mission_clear("mara", Profile.MARA_MINE) != OK:
		return _fail("A legacy save could not retain its clear without the reveal.")
	var old := Profile.new(path)
	if old.greyhollow_reveal_pending() or old.completed_missions("mara") != PackedStringArray([Profile.MARA_MINE]):
		return _fail("The older Mine clear wrongly armed the new reveal.")
	if old.record_mission_clear("raska", "orc_mine_witness") != OK:
		return _fail("Could not seed the separate Orc progress.")
	var before := FileAccess.get_file_as_string(path)
	if DirAccess.make_dir_absolute(path + ".tmp") != OK:
		return _fail("Could not set up the failed write.")
	if old.record_greyhollow_rescue_clear() == OK or old.greyhollow_reveal_pending() or FileAccess.get_file_as_string(path) != before:
		return _fail("A failed atomic write changed existing progress or armed an in-memory reveal.")
	DirAccess.remove_absolute(path + ".tmp")
	if old.record_greyhollow_rescue_clear() != OK:
		return _fail("A genuine rescue failed to save.")
	var reopened := Profile.new(path)
	if not reopened.greyhollow_reveal_pending() or reopened.completed_missions("mara") != PackedStringArray([Profile.MARA_MINE]):
		return _fail("A saved authentic rescue did not keep one clear and a pending reveal.")
	if reopened.completed_missions("raska") != PackedStringArray(["orc_mine_witness"]):
		return _fail("Saving the Human rescue changed Orc progress.")
	if reopened.finish_greyhollow_reveal() != OK or Profile.new(path).greyhollow_reveal_pending():
		return _fail("A deliberate finish did not persist the acknowledgement.")
	before = FileAccess.get_file_as_string(path)
	return (reopened.finish_greyhollow_reveal() == OK and reopened.record_greyhollow_rescue_clear() == OK
		and not reopened.greyhollow_reveal_pending() and FileAccess.get_file_as_string(path) == before) \
		or _fail("A repeated acknowledgement or replay changed profile bytes.")


func _fail(message: String) -> bool:
	push_error(message)
	return false
