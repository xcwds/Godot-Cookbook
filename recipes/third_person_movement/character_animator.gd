extends Node
## Drives the AnimationTree from the character's state and velocity, so the
## movement code does not know which animations exist. Replace or edit this
## when you swap the model.

## AnimationTree state to play for each movement state. Dash keeps whatever
## was playing.
const ANIMATION_FOR_STATE := {
	&"Ground": &"Locomotion",
	&"Air": &"Air",
	&"WallSlide": &"WallSlide",
}
const STRAFE_ANIMATION := &"Strafe"

@export var character: ThirdPersonCharacter
@export var animation_tree: AnimationTree

var _current := &""

@onready
var _playback: AnimationNodeStateMachinePlayback = animation_tree.get(&"parameters/playback")


func _process(_delta: float) -> void:
	var state := character.state_machine.state
	if state == null:
		return
	var target: StringName = ANIMATION_FOR_STATE.get(state.name, _current)
	if target == &"Locomotion" and character.strafe:
		target = STRAFE_ANIMATION
	if target != _current and target != &"":
		_current = target
		_playback.travel(target)

	var horizontal := (
		Vector3(character.velocity.x, 0.0, character.velocity.z) / maxf(character.speed, 0.001)
	)
	animation_tree.set("parameters/Locomotion/blend_position", minf(horizontal.length(), 1.0))
	# Velocity relative to where the model faces: x is right, y is back.
	var local := horizontal.rotated(Vector3.UP, -character.model.rotation.y)
	animation_tree.set("parameters/Strafe/blend_position", Vector2(local.x, local.z).limit_length())
