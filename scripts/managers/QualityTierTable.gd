class_name QualityTierTable extends Resource

## Container that holds tier settings indexed by graphics_quality.

@export var tiers: Array = []


## Get the tier for a given graphics quality level.
## Returns tier 0 if quality is out of range.
func get_tier(quality: int) -> QualityTierData:
	if quality < 0 or quality >= tiers.size():
		push_error("Invalid quality tier %d, returning tier 0" % quality)
		return tiers[0] if tiers.size() > 0 else null
	return tiers[quality]
