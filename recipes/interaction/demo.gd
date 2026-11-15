extends Node3D
## Two things to interact with: a switch that can be used again and again,
## and pickups that are used up.

var _collected := 0

@onready var _lamp: MeshInstance3D = $Lamp
@onready var _counter: Label = %Counter


func _ready() -> void:
	$Switch/Interactable.interacted.connect(_on_switch_used)
	for pickup in $Pickups.get_children():
		var interactable: Interactable = pickup.get_node("Interactable")
		interactable.interacted.connect(_on_pickup_taken.bind(pickup))


func _on_switch_used(_actor: Node) -> void:
	var material: StandardMaterial3D = _lamp.get_surface_override_material(0)
	material.emission_enabled = not material.emission_enabled
	$Switch/Interactable.prompt = "Turn off" if material.emission_enabled else "Turn on"


func _on_pickup_taken(_actor: Node, pickup: Node3D) -> void:
	_collected += 1
	_counter.text = "Collected: %d" % _collected
	pickup.queue_free()
