extends Node

## Purpose: restrained opt-in handheld feedback for mobile-only game events.
## Dependencies: SettingsManager. Android requires the VIBRATE export permission.

const TAP := {"duration": 12, "amplitude": 0.18}
const AVAILABLE := {"duration": 20, "amplitude": 0.28}
const READY := {"duration": 25, "amplitude": 0.32}
const DAMAGE := {"duration": 45, "amplitude": 0.48}
const REWARD := {"duration": 32, "amplitude": 0.38}

func play(kind: Dictionary) -> void:
	if OS.has_feature("pc") or not SettingsManager.haptics_enabled:
		return
	Input.vibrate_handheld(int(kind.duration), float(kind.amplitude))

func tap() -> void: play(TAP)
func available() -> void: play(AVAILABLE)
func ready() -> void: play(READY)
func damage() -> void: play(DAMAGE)
func reward() -> void: play(REWARD)
