@tool
class_name CosmeticData extends Resource

## CosmeticData
## Schema for one purely-visual cosmetic item (M16 §5). Never a stat, modifier,
## collision/hitbox reference, or camera value — test_cosmetics.gd enforces
## this by rejecting any authored property outside this exact schema.

@export var id: StringName = &""                # unique; collision is a load-time error (Req 2.6)
@export var display_name: String = ""
@export var description: String = ""
@export_enum("hull", "sails", "flag", "figurehead", "decoration") var slot: String = "hull"
@export var rarity_label: String = ""            # cosmetic label only, never a stat
@export var icon: Texture2D
@export var default_owned: bool = false

@export_group("Visual payload")
@export var albedo_texture: Texture2D            # hull / sails
@export var tint: Color = Color.WHITE
@export var mesh_override: PackedScene           # figurehead / decoration only
