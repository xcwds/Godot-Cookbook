class_name Interactor
extends Area3D
## Lets a character use [Interactable]s. It focuses the nearest one inside
## its collision shape and triggers it on the interact action.

## Emitted when the focused interactable changes. [param interactable] is
## null when nothing is in reach.
signal focus_changed(interactable: Interactable)

## Input action that triggers the focused interactable.
@export var interact_action := &"interact"
## Who is passed to [signal Interactable.interacted]. Defaults to the parent.
@export var actor: Node
## Optional node whose -Z axis is "forward". When set, only interactables
## within [member max_angle_degrees] of that direction can be focused.
@export var facing: Node3D
@export_range(0.0, 180.0) var max_angle_degrees := 75.0

## The interactable that would be used right now, or null.
var focused: Interactable

var _has_focus := false


func _ready() -> void:
	if actor == null:
		actor = get_parent()


func _physics_process(_delta: float) -> void:
	_set_focused(_find_best())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interact_action) and interact():
		get_viewport().set_input_as_handled()


## Uses the focused interactable. Returns false when there is none.
func interact() -> bool:
	if not is_instance_valid(focused) or not focused.enabled:
		return false
	focused.interact(actor)
	return true


func _find_best() -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for area in get_overlapping_areas():
		var interactable := area as Interactable
		if interactable == null or not interactable.enabled:
			continue
		var offset := interactable.global_position - global_position
		if facing != null and not _is_in_front(offset):
			continue
		var distance := offset.length_squared()
		if distance < best_distance:
			best = interactable
			best_distance = distance
	return best


func _is_in_front(offset: Vector3) -> bool:
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return true
	var forward := -facing.global_basis.z
	forward.y = 0.0
	return forward.angle_to(offset) <= deg_to_rad(max_angle_degrees)


func _set_focused(interactable: Interactable) -> void:
	# A focused interactable that was freed counts as lost focus, which the
	# reference alone cannot show: it already compares equal to null.
	var current: Interactable = focused if is_instance_valid(focused) else null
	if interactable == current and _has_focus == (current != null):
		return
	if current != null:
		current.unfocused.emit()
	focused = interactable
	_has_focus = focused != null
	if focused != null:
		focused.focused.emit()
	focus_changed.emit(focused)
