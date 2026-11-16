extends Label
## A pooled label that shows how often it has been used and returns itself to
## its pool after a moment.

const LIFETIME := 1.5

var _uses := 0


## Starts it afresh: an acquired instance is as it was when it was released.
func appear(at: Vector2) -> void:
	_uses += 1
	position = at
	text = "use %d" % _uses
	modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.tween_callback(ObjectPool.release_or_free.bind(self))
