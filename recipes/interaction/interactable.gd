class_name Interactable
extends Area3D
## Marks something the player can interact with. Give it a collision shape
## that covers where the player has to stand, and connect to
## [signal interacted] to make it do something.

## Emitted when an [Interactor] uses this. [param actor] is who did it.
signal interacted(actor: Node)
## Emitted when this becomes the thing an [Interactor] would use.
signal focused
## Emitted when it stops being that.
signal unfocused

## What the prompt says, for example "Open" or "Pick up".
@export var prompt := "Interact"
## Turn off to make this ignore interactors, for example once it is used up.
@export var enabled := true


func interact(actor: Node) -> void:
	if enabled:
		interacted.emit(actor)
