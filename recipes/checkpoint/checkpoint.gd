class_name Checkpoint
extends Area3D
## A place to respawn. When a body that has a [Respawner] walks in, this
## becomes that respawner's checkpoint.

signal activated
signal deactivated

@export var inactive_color := Color(0.5, 0.5, 0.55)
@export var active_color := Color(0.2, 0.9, 0.4)

var is_active := false

var _pad_material := StandardMaterial3D.new()

@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _pad: MeshInstance3D = get_node_or_null("Pad")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _pad != null:
		_pad.set_surface_override_material(0, _pad_material)
	_update_pad()


## Where a body respawning here should be placed.
func get_spawn_transform() -> Transform3D:
	return _spawn_point.global_transform


## Called by the [Respawner]; use [method Respawner.set_checkpoint] instead.
func set_active(active: bool) -> void:
	if active == is_active:
		return
	is_active = active
	_update_pad()
	if is_active:
		activated.emit()
	else:
		deactivated.emit()


func _on_body_entered(body: Node3D) -> void:
	var respawner := Respawner.find_for(body)
	if respawner != null:
		respawner.set_checkpoint(self)


func _update_pad() -> void:
	_pad_material.albedo_color = active_color if is_active else inactive_color
