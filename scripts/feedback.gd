extends Node
## Autoload. Soft sounds and vibration for game events, both switchable in the
## settings. The sounds are short tones built in code, so the game ships no
## audio files.

const MIX_RATE := 22050
const VOLUME_DB := -10.0

## event -> notes as [frequency in Hz, duration in seconds]
const TUNES := {
	"found": [[660.0, 0.08], [880.0, 0.14]],
	"miss": [[196.0, 0.12]],
	"hint": [[988.0, 0.07], [784.0, 0.12]],
	"win": [[523.0, 0.10], [659.0, 0.10], [784.0, 0.10], [1047.0, 0.24]],
	"button": [[520.0, 0.04]],
}
## event -> vibration length in milliseconds
const BUZZES := {"found": 40, "miss": 15, "win": 120}

var _player: AudioStreamPlayer
var _streams := {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	add_child(_player)
	for event: String in TUNES:
		_streams[event] = _build_stream(TUNES[event])


## Plays the sound and vibration of a game event, if the settings allow them.
func notify(event: String) -> void:
	var settings := get_node_or_null("/root/GameSettings")
	var sound_on: bool = settings == null or settings.sound_enabled
	var vibration_on: bool = settings == null or settings.vibration_enabled
	if sound_on and _streams.has(event):
		_player.stream = _streams[event]
		_player.play()
	if vibration_on and BUZZES.has(event):
		Input.vibrate_handheld(BUZZES[event])


## 16-bit mono sine tones with a short fade in and a longer fade out, so they
## start and end without a click.
static func _build_stream(notes: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for note: Array in notes:
		var frequency: float = note[0]
		var count := int(float(note[1]) * MIX_RATE)
		for i in count:
			var position := float(i) / count
			var envelope := minf(position / 0.08, 1.0) * minf((1.0 - position) / 0.35, 1.0)
			var sample := sin(TAU * frequency * i / MIX_RATE) * envelope * 0.6
			var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
			data.append(value & 0xFF)
			data.append((value >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
