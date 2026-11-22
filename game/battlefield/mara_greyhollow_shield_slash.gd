extends "res://game/battlefield/mara_greyhollow_rescue.gd"
## Exact campaign scene's optional presentation, not a new simulation owner.
## Keep the reviewed rescue/trio hosts and legacy Mine presenters untouched.

const ShieldSlashArt := preload("res://game/battlefield/mara_shield_slash_art.gd")

var _shield_slash: ShieldSlashArt
var _shield_pose_step := 0.0
var _shield_order_battle: Battle


func _reset_encounter() -> void:
	# Retry replaces the CommandBattle before rebuilding this encounter.
	if _shield_order_battle and _shield_order_battle.formation_commanded.is_connected(_cancel_shield_slash_on_command):
		_shield_order_battle.formation_commanded.disconnect(_cancel_shield_slash_on_command)
	_shield_order_battle = null
	if _shield_slash:
		_shield_slash.cancel()
		_shield_slash = null
	super._reset_encounter()
	if not encounter or scene_file_path != "res://game/battlefield/mara_greyhollow_rescue_campaign.tscn" \
		or not render_shield_infantry or _heavy_replay_loadout:
		return
	var presenter := ShieldSlashArt.new()
	if not presenter.configure(encounter.infantry_attack, _infantry_animators,
		battle.formations[InfantryAttack.INFANTRY_INDEX]):
		return
	_shield_slash = presenter
	_shield_order_battle = battle
	if not battle.formation_commanded.is_connected(_cancel_shield_slash_on_command):
		battle.formation_commanded.connect(_cancel_shield_slash_on_command)


func _after_battle_step(delta: float) -> void:
	_shield_pose_step = delta
	super._after_battle_step(delta)


func _sync_infantry_animation(reset := false) -> void:
	if _shield_slash:
		if reset:
			_shield_slash.cancel()
		elif _shield_slash.sync(_shield_pose_step, battle.formations[InfantryAttack.INFANTRY_INDEX]):
			return
	super._sync_infantry_animation(reset)


func _cancel_shield_slash_on_command(index: int) -> void:
	if _shield_slash and index == InfantryAttack.INFANTRY_INDEX and _shield_slash.cancel():
		super._sync_infantry_animation()
