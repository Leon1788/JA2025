# res://Managers/SoundManager.gd
## Zentrale Audio-Verwaltung
## KORRIGIERT: linear2db() -> linear_to_db()

extends IManager

var master_bus_index: int = -1
var effects_bus_index: int = -1
var music_bus_index: int = -1

var master_volume: float = 1.0
var effects_volume: float = 0.8
var music_volume: float = 0.6

func _ready() -> void:
	super._ready()
	
	self.name = "SoundManager"
	
	_find_audio_buses()
	_update_audio_buses()
	
	_debug_log("SoundManager initialized")

func _find_audio_buses() -> void:
	var audio_server = AudioServer
	
	master_bus_index = audio_server.get_bus_index("Master")
	effects_bus_index = audio_server.get_bus_index("Effects")
	music_bus_index = audio_server.get_bus_index("Music")
	
	if master_bus_index == -1:
		_debug_log("Master bus not found (that's OK, will create default)")

func _update_audio_buses() -> void:
	var audio_server = AudioServer
	
	if master_bus_index >= 0:
		audio_server.set_bus_mute(master_bus_index, false)
		audio_server.set_bus_volume_db(master_bus_index, linear_to_db(master_volume))
	
	if effects_bus_index >= 0:
		audio_server.set_bus_volume_db(effects_bus_index, linear_to_db(effects_volume))
	
	if music_bus_index >= 0:
		audio_server.set_bus_volume_db(music_bus_index, linear_to_db(music_volume))

# ============================================================================
# SOUND PLAYBACK
# ============================================================================

func play_sound_effect(sound_path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio_stream_player = AudioStreamPlayer.new()
	
	var sound = load(sound_path)
	if sound == null:
		_report_warning("Could not load sound: %s" % sound_path)
		return
	
	audio_stream_player.stream = sound
	audio_stream_player.bus = "Effects"
	audio_stream_player.volume_db = volume_db
	audio_stream_player.pitch_scale = pitch_scale
	
	add_child(audio_stream_player)
	audio_stream_player.play()
	
	await audio_stream_player.finished
	audio_stream_player.queue_free()
	
	_debug_log("Playing sound: %s" % sound_path)

func play_sound_effect_3d(sound_path: String, position: Vector3, volume_db: float = 0.0) -> void:
	var audio_stream_player_3d = AudioStreamPlayer3D.new()
	
	var sound = load(sound_path)
	if sound == null:
		_report_warning("Could not load sound: %s" % sound_path)
		return
	
	audio_stream_player_3d.stream = sound
	audio_stream_player_3d.bus = "Effects"
	audio_stream_player_3d.volume_db = volume_db
	audio_stream_player_3d.global_position = position
	
	add_child(audio_stream_player_3d)
	audio_stream_player_3d.play()
	
	await audio_stream_player_3d.finished
	audio_stream_player_3d.queue_free()

# ============================================================================
# VOLUME CONTROL
# ============================================================================

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	_update_audio_buses()
	_debug_log("Master volume set to: %.2f" % master_volume)

func set_effects_volume(volume: float) -> void:
	effects_volume = clamp(volume, 0.0, 1.0)
	_update_audio_buses()
	_debug_log("Effects volume set to: %.2f" % effects_volume)

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	_update_audio_buses()
	_debug_log("Music volume set to: %.2f" % music_volume)

func get_volumes() -> Dictionary:
	return {
		"master": master_volume,
		"effects": effects_volume,
		"music": music_volume
	}

# ============================================================================
# SOUND EVENTS (für KI)
# ============================================================================

func emit_sound_event(position: Vector3, volume: float, source: IEntity = null) -> void:
	if GameController.current_event_bus:
		GameController.current_event_bus.sound_event.emit(position, volume, source)
	
	_debug_log("Sound event emitted at " + str(position) + " with volume " + str(volume))

func emit_gunshot(position: Vector3, shooter: IEntity, weapon_name: String, is_silenced: bool = false) -> void:
	var volume = GameConstants.SOUND_VOLUME_GUNSHOT
	
	if is_silenced:
		volume = GameConstants.SOUND_VOLUME_GUNSHOT_SILENCED
	
	emit_sound_event(position, volume, shooter)

func emit_footstep(position: Vector3, walker: IEntity) -> void:
	emit_sound_event(position, GameConstants.SOUND_VOLUME_FOOTSTEP, walker)

func emit_reload(position: Vector3, reloader: IEntity) -> void:
	emit_sound_event(position, GameConstants.SOUND_VOLUME_RELOAD, reloader)

# ============================================================================
# MANAGER INTERFACE (von IManager)
# ============================================================================

func on_manager_activate() -> void:
	super.on_manager_activate()

func on_manager_deactivate() -> void:
	super.on_manager_deactivate()

func on_game_reset() -> void:
	super.on_game_reset()
	master_volume = 1.0
	effects_volume = 0.8
	music_volume = 0.6
	_update_audio_buses()
	_debug_log("SoundManager reset")
