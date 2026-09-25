class_name ShipProgressionConfig extends Resource

## Purpose: the catalog of upgradable ship components (M23 Requirement 3),
## loaded once by OwnedShipData.get_component_catalog(). Adding a sixth part
## is one new ShipComponentData .tres appended here — no code change.

@export var components: Array[ShipComponentData] = []


func get_component(component_id: String) -> ShipComponentData:
	for c in components:
		if c and c.component_id == component_id:
			return c
	return null


func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for c in components:
		if c:
			ids.append(c.component_id)
	return ids
