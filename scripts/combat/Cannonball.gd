class_name Cannonball extends RigidBody3D

@export var damage: float = 15.0
@export var lifetime: float = 5.0

var source_ship: Node = null

func _ready() -> void:
	# Enable contact reporting to detect hits
	contact_monitor = true
	max_contacts_reported = 1
	
	# Connect to collision signal
	body_entered.connect(_on_body_entered)
	
	# Despawn after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	# Ignore collision with the ship that fired this
	if body == source_ship:
		return
		
	# Check if body has a ShipCombat component
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_node("ShipCombat"):
		var combat = body.get_node("ShipCombat")
		if combat.has_method("take_damage"):
			combat.take_damage(damage)
			
	# Spawn impact effect here later
	
	queue_free()
