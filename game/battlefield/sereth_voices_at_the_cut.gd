extends RefCounted
## Objective rules for The Names at the Cut. The witness's testimony and the
## portable records are independent; this model does not identify the voices.

const MISSION_ID := &"sereth_voices_at_the_cut"

enum Interaction { NONE, LISTEN_TO_IREN, RELAY_ACCOUNT, PICK_UP_BUNDLE, SECURE_BUNDLE }
enum AccountStatus { UNHEARD, HEARD, RELAYED, FILED }
enum BundleStatus { EXPOSED, WITH_SERETH, WITH_ENEMY, DROPPED, SECURED, EXTRACTED }
enum Outcome { ACTIVE, SUCCEEDED, FAILED }
enum Failure { NONE, SERETH_FELL, BUNDLE_EXTRACTED }


class Observation:
	## A field-hero input; the battlefield samples these contacts at distinct markers.
	var hero_interaction := Interaction.NONE
	var sereth_at_witness_account := false
	var sereth_at_account_entry := false
	var sereth_at_bundle := false
	var sereth_at_bundle_secure := false
	var clerk_at_entry := false
	var record_room_contested := false
	## A visibly enacted pickup at the actual records, not enemy presence in the room.
	var enemy_took_bundle := false
	var enemy_dropped_bundle := false
	## The tracked enemy carrier reached EnemyRetreatExit while carrying the bundle.
	var enemy_carrier_at_retreat_exit := false
	var sereth_fell := false


var outcome: Outcome:
	get:
		return _outcome

var account_status: AccountStatus:
	get:
		return _account_status

var bundle_status: BundleStatus:
	get:
		return _bundle_status

var failure: Failure:
	get:
		return _failure

var _outcome := Outcome.ACTIVE
var _account_status := AccountStatus.UNHEARD
var _bundle_status := BundleStatus.EXPOSED
var _failure := Failure.NONE


## The battlefield reports once after moving actors and checking objective contacts.
## A confirmed loss takes priority over same-update deposition or filing.
func advance(observation: Observation) -> Outcome:
	if _outcome != Outcome.ACTIVE:
		return _outcome
	if observation.sereth_fell:
		return _fail(Failure.SERETH_FELL)
	if _bundle_status == BundleStatus.WITH_ENEMY and observation.enemy_carrier_at_retreat_exit:
		_bundle_status = BundleStatus.EXTRACTED
		return _fail(Failure.BUNDLE_EXTRACTED)

	_advance_account(observation)
	_advance_bundle(observation)
	if _account_status == AccountStatus.FILED and _bundle_status == BundleStatus.SECURED:
		_outcome = Outcome.SUCCEEDED
	return _outcome


func restart() -> void:
	_outcome = Outcome.ACTIVE
	_account_status = AccountStatus.UNHEARD
	_bundle_status = BundleStatus.EXPOSED
	_failure = Failure.NONE


func _advance_account(observation: Observation) -> void:
	match _account_status:
		AccountStatus.UNHEARD:
			if observation.hero_interaction == Interaction.LISTEN_TO_IREN and observation.sereth_at_witness_account:
				_account_status = AccountStatus.HEARD
		AccountStatus.HEARD:
			if observation.hero_interaction == Interaction.RELAY_ACCOUNT and observation.sereth_at_account_entry \
					and observation.clerk_at_entry:
				_account_status = AccountStatus.RELAYED
		AccountStatus.RELAYED:
			# Pressure pauses the clerk, but doesn't erase an already relayed account.
			if observation.clerk_at_entry and not observation.record_room_contested:
				_account_status = AccountStatus.FILED


func _advance_bundle(observation: Observation) -> void:
	match _bundle_status:
		BundleStatus.EXPOSED, BundleStatus.DROPPED:
			# A valid hero recovery wins a simultaneous pickup from the ground.
			if observation.hero_interaction == Interaction.PICK_UP_BUNDLE and observation.sereth_at_bundle:
				_bundle_status = BundleStatus.WITH_SERETH
			elif observation.enemy_took_bundle:
				_bundle_status = BundleStatus.WITH_ENEMY
		BundleStatus.WITH_SERETH:
			if observation.hero_interaction == Interaction.SECURE_BUNDLE and observation.sereth_at_bundle_secure \
					and not observation.record_room_contested:
				_bundle_status = BundleStatus.SECURED
		BundleStatus.WITH_ENEMY:
			if observation.enemy_dropped_bundle:
				_bundle_status = BundleStatus.DROPPED
		BundleStatus.SECURED:
			if observation.record_room_contested and observation.enemy_took_bundle:
				_bundle_status = BundleStatus.WITH_ENEMY


func _fail(reason: Failure) -> Outcome:
	_failure = reason
	_outcome = Outcome.FAILED
	return _outcome
