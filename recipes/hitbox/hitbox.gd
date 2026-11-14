class_name Hitbox
extends Area3D
## The part of something that deals damage: a weapon swing, a projectile, a
## spike trap. It hits every [Hurtbox] it overlaps while [member active].

## Emitted for each hit that got through.
signal hit_landed(hurtbox: Hurtbox)

@export var damage := 1.0
## Hurtboxes with the same team are ignored. Empty belongs to no team.
@export var team := &""
## Turn on only while an attack should connect, for example from an
## animation. Turning it on hits whatever is already inside.
@export var active := true:
	set(value):
		active = value
		if not active:
			_since_hit.clear()
## Seconds between hits on a hurtbox that stays inside. 0 hits it once per
## visit (or once per activation).
@export var hit_interval := 0.0

## Seconds since each overlapping hurtbox was last hit.
var _since_hit: Dictionary[Hurtbox, float] = {}


func _ready() -> void:
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null:
			continue
		if not _since_hit.has(hurtbox):
			_hit(hurtbox)
			continue
		_since_hit[hurtbox] += delta
		if hit_interval > 0.0 and _since_hit[hurtbox] >= hit_interval:
			_hit(hurtbox)


func _hit(hurtbox: Hurtbox) -> void:
	_since_hit[hurtbox] = 0.0
	if hurtbox.take_hit(self):
		hit_landed.emit(hurtbox)


func _on_area_exited(area: Area3D) -> void:
	_since_hit.erase(area)
