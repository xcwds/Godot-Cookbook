# Interaction

Walk up to something, see a prompt, press a button. Three small pieces:

- `Interactable`: an `Area3D` you put on anything that can be used. It emits `interacted`.
- `Interactor`: an `Area3D` on the character. It focuses the nearest interactable in reach and triggers it on the `interact` action.
- `InteractionPrompt`: a UI label that shows `[E] Open` while something is in reach.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Add an `interact` input action (E and gamepad X in the cookbook project) and name physics layer 3 `interactable`.
3. Instance `interactor.tscn` as a child of your character. Resize its collision shape to the reach you want.
4. Instance `interactable.tscn` as a child of each usable object, set its `prompt`, resize its shape, and connect `interacted`:

```gdscript
func _ready() -> void:
	$Interactable.interacted.connect(_on_used)


func _on_used(actor: Node) -> void:
	print("%s opened the chest" % actor.name)
	$Interactable.enabled = false
```

5. Instance `interaction_prompt.tscn` in your UI and set its `interactor`.

## Requirements

| Kind | Needed |
|---|---|
| Input actions | `interact` |
| Physics layers | Interactables are on layer 3; the interactor only looks at layer 3. Nothing else needs to change. |

## Settings

| Member | On | Purpose |
|---|---|---|
| `prompt` | `Interactable` | Text for the prompt, such as "Open". Can be changed at any time. |
| `enabled` | `Interactable` | Turn off to be ignored, for example once used up. |
| `interacted(actor)`, `focused`, `unfocused` | `Interactable` | Signals. Use the focus pair for a highlight. |
| `interact_action` | `Interactor` | Input action that triggers the focused interactable. |
| `actor` | `Interactor` | Who is passed to `interacted`. Defaults to the interactor's parent. |
| `facing`, `max_angle_degrees` | `Interactor` | Optional. Set `facing` to the node that turns with the character, and only interactables in front of it can be focused. |
| `focused`, `focus_changed(interactable)`, `interact()` | `Interactor` | Current focus, a signal when it changes, and triggering from code. |
| `interactor` | `InteractionPrompt` | The interactor to show prompts for. |

## Where to take it next

- Reach is the two overlapping shapes, so walls do not block it. Add a raycast from the interactor to the candidate in `_find_best()`.
- It is proximity based. For "look at it to use it", replace the area with a raycast from the camera and keep the rest.
- One press, one use. There is no hold-to-interact or progress.
- The prompt shows the first key bound to the action, not gamepad glyphs, and does not switch when the player changes device.
- Nothing is highlighted in the world; connect `focused` and `unfocused` to an outline or a glow.
