extends GutTest

## M17 Task 22 — RewardedBonusOffer, the one reusable panel behind all three
## rewarded surfaces. Requirement 6.4 (no re-prompt/no confirmation on
## decline), 6.7 (ad-free short-circuit), 6.8 (failure keeps the baseline
## and the offer).

const RewardedBonusOfferScene := preload("res://scenes/ui/RewardedBonusOffer.tscn")
const _SURFACE := &"offline_double"

var _offer: RewardedBonusOffer
var _saved_ledger: Dictionary
var _saved_ad_free: bool
var _saved_ad_state: AdManager.State


func before_each():
	_saved_ledger = AdManager._ledger.duplicate(true)
	AdManager._ledger.clear()
	AdManager._backend.next_ad_result = "complete"
	_saved_ad_free = EntitlementManager.has_entitlement(EntitlementManager.AD_FREE_ID)
	if _saved_ad_free:
		EntitlementManager.revoke(EntitlementManager.AD_FREE_ID)
	# These tests are about the ad-request/response flow itself, not the
	# permission gate (test_ad_gating.gd owns that) — start already resolved
	# so request_bonus() actually reaches the backend instead of reporting
	# unavailable and triggering the age gate.
	_saved_ad_state = AdManager.state
	AdManager.state = AdManager.State.READY_PERSONALIZED


func after_each():
	get_tree().paused = false
	AdManager._ledger = _saved_ledger.duplicate(true)
	AdManager.state = _saved_ad_state
	if is_instance_valid(_offer):
		_offer.queue_free()
	_offer = null
	if _saved_ad_free and not EntitlementManager.has_entitlement(EntitlementManager.AD_FREE_ID):
		EntitlementManager.grant(EntitlementManager.AD_FREE_ID, "test")


func test_present_shows_the_panel_and_pauses():
	_offer = RewardedBonusOfferScene.instantiate()
	add_child(_offer)
	_offer.present(_SURFACE, "Double it?", func(): pass)
	assert_true(_offer.visible)
	assert_true(get_tree().paused)


func test_present_does_nothing_when_the_surface_is_capped():
	AdManager._ledger[AdManager._today_key()] = {_SURFACE: AdManager.SURFACE_DAILY_CAPS[_SURFACE]}
	_offer = RewardedBonusOfferScene.instantiate()
	add_child(_offer)
	_offer.present(_SURFACE, "Double it?", func(): pass)
	assert_false(_offer.visible, "a capped surface must never show an offer at all")


func test_decline_closes_without_granting_the_bonus():
	var granted := [false]
	_offer = RewardedBonusOfferScene.instantiate()
	add_child(_offer)
	_offer.present(_SURFACE, "Double it?", func(): granted[0] = true)
	_offer.decline_button.pressed.emit()
	await wait_process_frames(1)
	assert_false(granted[0])
	assert_false(get_tree().paused)


func test_watching_a_completed_ad_grants_the_bonus_and_closes():
	var granted := [false]
	_offer = RewardedBonusOfferScene.instantiate()
	add_child(_offer)
	_offer.present(_SURFACE, "Double it?", func(): granted[0] = true)
	_offer.watch_button.pressed.emit()
	await wait_for_signal(AdManager.bonus_granted, 1.0)
	assert_true(granted[0])


func test_a_failed_ad_keeps_the_offer_available_and_does_not_grant():
	AdManager._backend.next_ad_result = "fail"
	var granted := [false]
	_offer = RewardedBonusOfferScene.instantiate()
	add_child(_offer)
	_offer.present(_SURFACE, "Double it?", func(): granted[0] = true)
	_offer.watch_button.pressed.emit()
	await wait_for_signal(AdManager.bonus_ad_failed, 1.0)
	assert_false(granted[0])
	assert_true(is_instance_valid(_offer) and _offer.visible,
		"a failed ad must not close the offer — the player can retry or decline")
	assert_false(_offer.watch_button.disabled, "the watch button must re-enable after a failure")


func test_ad_free_entitlement_grants_immediately_with_no_ad_shown():
	EntitlementManager.grant(EntitlementManager.AD_FREE_ID, "test")
	var granted := [false]
	_offer = RewardedBonusOfferScene.instantiate()
	add_child(_offer)
	_offer.present(_SURFACE, "Double it?", func(): granted[0] = true)
	_offer.watch_button.pressed.emit()
	await wait_process_frames(2)
	assert_true(granted[0])
	EntitlementManager.revoke(EntitlementManager.AD_FREE_ID)
