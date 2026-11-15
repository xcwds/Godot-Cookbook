class_name ThirdPersonCharacterState
extends State
## Base class for the movement states: gives them the character and the
## names of the other states.

const GROUND := &"Ground"
const AIR := &"Air"
const DASH := &"Dash"
const WALL_SLIDE := &"WallSlide"

var character: ThirdPersonCharacter


func _ready() -> void:
	character = owner as ThirdPersonCharacter
	assert(character != null, "Movement states must be inside a ThirdPersonCharacter scene.")
