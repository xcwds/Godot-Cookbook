extends Control
## The settings menu, plus a beep on the SFX bus to hear the volume sliders.

const TONE_HZ := 440.0
const TONE_SECONDS := 0.3

@onready var _player: AudioStreamPlayer = $TonePlayer
@onready var _status: Label = %Status


func _ready() -> void:
	# In a real game, call this once at startup, before any menu exists.
	GameSettings.load_and_apply()
	%TestSound.pressed.connect(_play_tone)
	$SettingsMenu.closed.connect(func() -> void: _status.text = "Back pressed.")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		_status.text = "Jump pressed (%s)." % GameSettings.get_binding_text(&"jump")


func _play_tone() -> void:
	_player.play()
	var playback: AudioStreamGeneratorPlayback = _player.get_stream_playback()
	var rate: float = _player.stream.mix_rate
	for i in int(rate * TONE_SECONDS):
		var sample := sin(TAU * TONE_HZ * i / rate) * 0.3
		playback.push_frame(Vector2(sample, sample))
