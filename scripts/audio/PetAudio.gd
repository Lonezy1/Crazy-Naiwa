extends Node

enum Effect {
	MENU_CLICK,
	POKE,
	DRAG_RELEASE,
	CORNER_BUMP,
	LAND,
	BURST,
	SWARM_SPAWN,
	SWARM_CLEAR,
}

const SAMPLE_RATE := 22050
const VOICE_COUNT := 6
const BUS_NAME := "Pet SFX"
const EFFECT_SPECS := {
	Effect.MENU_CLICK: {"duration": 0.045, "start_hz": 1180.0, "end_hz": 860.0, "gain": 0.34, "harmonic": 0.0, "noise": 0.0, "decay": 1.8},
	Effect.POKE: {"duration": 0.11, "start_hz": 520.0, "end_hz": 390.0, "gain": 0.36, "harmonic": 0.14, "noise": 0.02, "decay": 1.7},
	Effect.DRAG_RELEASE: {"duration": 0.2, "start_hz": 290.0, "end_hz": 720.0, "gain": 0.3, "harmonic": 0.08, "noise": 0.0, "decay": 2.0},
	Effect.CORNER_BUMP: {"duration": 0.13, "start_hz": 210.0, "end_hz": 145.0, "gain": 0.37, "harmonic": 0.3, "noise": 0.16, "decay": 1.5},
	Effect.LAND: {"duration": 0.2, "start_hz": 165.0, "end_hz": 95.0, "gain": 0.36, "harmonic": 0.32, "noise": 0.12, "decay": 1.7},
	Effect.BURST: {"duration": 0.34, "start_hz": 380.0, "end_hz": 980.0, "gain": 0.34, "harmonic": 0.12, "noise": 0.015, "decay": 1.9},
	Effect.SWARM_SPAWN: {"duration": 0.22, "start_hz": 310.0, "end_hz": 920.0, "gain": 0.3, "harmonic": 0.1, "noise": 0.01, "decay": 1.8},
	Effect.SWARM_CLEAR: {"duration": 0.18, "start_hz": 880.0, "end_hz": 320.0, "gain": 0.28, "harmonic": 0.08, "noise": 0.0, "decay": 2.0},
}
const EFFECT_COOLDOWNS_MS := {
	Effect.MENU_CLICK: 35,
	Effect.POKE: 45,
	Effect.CORNER_BUMP: 120,
	Effect.LAND: 100,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_played_msec: Dictionary = {}
var _bus_index := -1
var _settings: Variant

func _ready() -> void:
	_settings = get_node("/root/PetSettings")
	_ensure_audio_bus()
	for effect in EFFECT_SPECS.keys():
		_streams[effect] = create_effect_stream(effect)
	for _voice_index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_players.append(player)
	sync_settings()

func sync_settings() -> void:
	if _bus_index < 0:
		return
	var volume := clampf(_settings.sfx_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(_bus_index, not _settings.sound_enabled or volume <= 0.0)
	AudioServer.set_bus_volume_db(_bus_index, linear_to_db(maxf(volume, 0.001)))

func play_effect(effect: int) -> bool:
	if not _settings.sound_enabled or _settings.sfx_volume <= 0.0 or not _streams.has(effect):
		return false
	var now_msec := Time.get_ticks_msec()
	var cooldown := int(EFFECT_COOLDOWNS_MS.get(effect, 0))
	if now_msec - int(_last_played_msec.get(effect, -100000)) < cooldown:
		return false
	for player in _players:
		if player.is_playing():
			continue
		player.stream = _streams[effect]
		player.play()
		_last_played_msec[effect] = now_msec
		return true
	return false

static func create_effect_stream(effect: int) -> AudioStreamWAV:
	if not EFFECT_SPECS.has(effect):
		return null
	var spec: Dictionary = EFFECT_SPECS[effect]
	var frame_count := maxi(1, roundi(float(spec["duration"]) * SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	var phase := 0.0
	for frame in range(frame_count):
		var progress := float(frame) / float(maxi(frame_count - 1, 1))
		var frequency := lerpf(float(spec["start_hz"]), float(spec["end_hz"]), progress)
		phase += TAU * frequency / SAMPLE_RATE
		var envelope := pow(maxf(0.0, 1.0 - progress), float(spec["decay"]))
		envelope *= minf(progress / 0.035, 1.0)
		var tone := sin(phase) + sin(phase * 2.0) * float(spec["harmonic"])
		var noise := sin(float(frame) * 12.9898) * sin(float(frame) * 78.233) * float(spec["noise"])
		var sample := clampf((tone + noise) * float(spec["gain"]) * envelope, -1.0, 1.0)
		pcm.encode_s16(frame * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

func _ensure_audio_bus() -> void:
	_bus_index = AudioServer.get_bus_index(BUS_NAME)
	if _bus_index >= 0:
		return
	_bus_index = AudioServer.bus_count
	AudioServer.add_bus(_bus_index)
	AudioServer.set_bus_name(_bus_index, BUS_NAME)
	AudioServer.set_bus_send(_bus_index, "Master")
