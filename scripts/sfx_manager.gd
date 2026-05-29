extends Node
## Autoload: lightweight procedural beeps (no audio files required).

var _player: AudioStreamPlayer
var _win_playing: bool = false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)


func play_tone(freq_hz: float, duration: float = 0.09, volume_db: float = -8.0) -> void:
	var stream := _make_tone(freq_hz, duration)
	if stream == null:
		return
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()


func play_key() -> void:
	play_tone(880.0, 0.07, -6.0)


func play_door() -> void:
	play_tone(520.0, 0.1, -6.0)


func play_rescue() -> void:
	play_tone(740.0, 0.06, -8.0)


func play_fruit() -> void:
	play_tone(620.0, 0.08, -6.0)
	var t := get_tree().create_timer(0.06)
	t.timeout.connect(func(): play_tone(980.0, 0.07, -7.0), CONNECT_ONE_SHOT)


func play_double_boost() -> void:
	play_tone(480.0, 0.1, -6.0)
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(func(): play_tone(820.0, 0.09, -6.0), CONNECT_ONE_SHOT)


func play_win() -> void:
	if _win_playing:
		return
	_win_playing = true
	play_tone(660.0, 0.12, -5.0)
	var t := get_tree().create_timer(0.12)
	t.timeout.connect(_play_win_second_tone, CONNECT_ONE_SHOT)


func _play_win_second_tone() -> void:
	play_tone(990.0, 0.18, -4.0)
	var done := get_tree().create_timer(0.2)
	done.timeout.connect(func(): _win_playing = false, CONNECT_ONE_SHOT)


func _make_tone(freq_hz: float, duration: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := maxi(1, int(mix_rate * duration))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var amp := 0.35
	for i in sample_count:
		var t := float(i) / float(mix_rate)
		var env := 1.0 - (float(i) / float(sample_count))
		var s := sin(TAU * freq_hz * t) * amp * env
		var v := int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav
