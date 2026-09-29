@tool
class_name ProductData extends Resource

## ProductData
## Maps one store SKU to the entitlement id(s) a successful purchase grants
## (design.md §2/§4), or — for an M27 consumable — the Pieces of Eight it adds. Never hardcoded in a script — every real SKU is
## authored as a .tres under resources/store/ (AGENTS.md: data-driven
## balance). tests/test_monetization_invariants.gd enforces that every id in
## entitlement_ids resolves in CosmeticCatalogue or is
## EntitlementManager.AD_FREE_ID — nothing else is ever purchasable.

@export var sku: StringName = &""
@export var display_name: String = ""
@export var entitlement_ids: Array[StringName] = []
## M27 — Pieces of Eight a purchase of this SKU adds (docs/17_MONETIZATION.md
## §2). 0 (the default for every non-consumable) = not a consumable. A consumable
## grants no entitlement (entitlement_ids stays empty) and can be bought again.
@export var grants_eights: int = 0
## Convenience/authoring flag mirroring whether EntitlementManager.AD_FREE_ID
## is present in entitlement_ids — kept as its own field (rather than derived)
## so AdManager/StoreScreen can check it without depending on
## EntitlementManager's constant, but the two must always agree; the
## invariant test enforces that agreement.
@export var is_ad_free: bool = false
