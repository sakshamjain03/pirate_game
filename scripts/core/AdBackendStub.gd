class_name AdBackendStub extends IAdBackend

## AdBackendStub
## Deterministic no-op ad backend for desktop and every GUT test. Models the
## consent-form outcome and the rewarded-ad lifecycle (load, fail, complete,
## dismiss) async and controllably, the same shape StoreBackendStub already
## proved out for billing.

var next_ad_result := "complete"          # "complete", "fail", "dismiss"
var next_ad_failure_reason := "stub_no_fill"

var sdk_initialized := false
var load_calls: Array[StringName] = []
var show_calls: Array[StringName] = []


func is_available() -> bool:
	return false


func initialize_sdk() -> void:
	sdk_initialized = true


func load_rewarded_ad(surface: StringName) -> void:
	load_calls.append(surface)
	call_deferred("emit_signal", "rewarded_ad_loaded", surface)


func show_rewarded_ad(surface: StringName) -> void:
	show_calls.append(surface)
	match next_ad_result:
		"fail":
			call_deferred("emit_signal", "rewarded_ad_failed", surface, next_ad_failure_reason)
		"dismiss":
			call_deferred("emit_signal", "rewarded_ad_dismissed", surface)
		_:
			call_deferred("emit_signal", "rewarded_ad_completed", surface)
