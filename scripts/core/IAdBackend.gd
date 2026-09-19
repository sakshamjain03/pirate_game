class_name IAdBackend extends RefCounted

## IAdBackend
## Platform-agnostic ad SDK interface, mirroring IStoreBackend's own shape
## (design.md's "one seam, testable headlessly" principle, extended to ads
## even though design.md §5 doesn't name this seam explicitly — AdManager
## must never reference a real ad SDK directly any more than StoreManager
## references a billing SDK directly). AdManagerBackendStub implements this
## for every headless test; a real network SDK plugin (AdMob-equivalent)
## implements it once one is vendored and an ad network account exists.
##
## Every method here is a no-op/false by default — a conforming backend only
## does real work once AdManager has already confirmed it's in a READY_*
## state (Requirement 5.5). The interface itself has no opinion on that; the
## state machine living in AdManager is what enforces it.

signal rewarded_ad_loaded(surface: StringName)
signal rewarded_ad_failed(surface: StringName, reason: String)
signal rewarded_ad_completed(surface: StringName)
signal rewarded_ad_dismissed(surface: StringName)


func is_available() -> bool:
	return false


func initialize_sdk() -> void:
	pass


func load_rewarded_ad(_surface: StringName) -> void:
	pass


func show_rewarded_ad(_surface: StringName) -> void:
	pass
