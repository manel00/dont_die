extends Node

## AudioManager (Autoload)
## Sistema de audio con SFX sintÃ©ticos procedurales para disparo, impacto, muerte y UI.

var _sfx_bus_idx: int = 0
var _music_bus_idx: int = 0

func _ready() -> void:
	_setup_audio_buses()

func _setup_audio_buses() -> void:
	# AÃ±adir bus SFX si no existe
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		_sfx_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(_sfx_bus_idx, "Master")
		AudioServer.set_bus_volume_db(_sfx_bus_idx, 0.0)
	else:
		_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	
	# AÃ±adir bus Music si no existe
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		_music_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_music_bus_idx, "Music")
		AudioServer.set_bus_send(_music_bus_idx, "Master")
		AudioServer.set_bus_volume_db(_music_bus_idx, -6.0)
	else:
		_music_bus_idx = AudioServer.get_bus_index("Music")

# â”€â”€ ReproducciÃ³n SFX sintÃ©ticos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func play_shoot() -> void:
	_play_synth_sfx(880.0, 0.05, 0.8, "SFX")

func play_impact() -> void:
	_play_synth_sfx(220.0, 0.08, 1.0, "SFX")

func play_enemy_death() -> void:
	_play_synth_sfx(110.0, 0.15, 1.2, "SFX")

func play_player_hurt() -> void:
	_play_synth_sfx(440.0, 0.12, 0.9, "SFX")

func play_level_up() -> void:
	_play_chord([523.0, 659.0, 784.0], 0.4, "SFX")

func play_magic_cast() -> void:
	_play_chord([440.0, 880.0, 1320.0], 0.2, "SFX")

func play_heal() -> void:
	_play_chord([660.0, 784.0, 988.0], 0.25, "SFX")

func play_explosion() -> void:
	for i in range(3):
		await get_tree().create_timer(i * 0.05).timeout
		_play_synth_sfx(80.0 + i * 30.0, 0.25, 1.5 - i * 0.3, "SFX")

# â”€â”€ Internos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _play_synth_sfx(frequency: float, duration: float, volume_db: float, bus: String) -> void:
	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = duration
	player.stream = gen
	player.bus = bus
	player.volume_db = volume_db * 10.0 - 10.0
	add_child(player)

	# FIX: Fill buffer BEFORE playing to avoid first-frame silence/garbage
	await get_tree().process_frame
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var samples_needed: int = int(gen.mix_rate * duration)
		var t: float = 0.0
		var dt: float = 1.0 / gen.mix_rate
		for _i in range(samples_needed):
			var sample: float = sin(t * frequency * TAU) * exp(-t * 8.0) * volume_db
			pb.push_frame(Vector2(sample, sample))
			t += dt

	# Now start playback after buffer is filled
	player.play()

	# Auto-limpiar
	var cleanup_timer := get_tree().create_timer(duration + 0.1)
	cleanup_timer.timeout.connect(player.queue_free)

func _play_chord(frequencies: Array, duration: float, bus: String) -> void:
	for freq in frequencies:
		_play_synth_sfx(freq, duration, 0.7, bus)
