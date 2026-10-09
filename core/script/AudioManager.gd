extends Node

const MUSIC_PATH := "res://asset/music/the_mountain-retro-game-593063.mp3"
const SETTINGS_PATH := "user://audio_settings.cfg"

var music_player: AudioStreamPlayer
var music_volume: float = 0.75

func _ready() -> void:
	_load_settings()
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	var music_stream := load(MUSIC_PATH) as AudioStreamMP3
	if music_stream:
		music_stream.loop = true
		music_player.stream = music_stream
	music_player.autoplay = false
	add_child(music_player)
	_apply_music_volume()
	music_player.play()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music_volume()
	_save_settings()

func get_music_volume() -> float:
	return music_volume

func _apply_music_volume() -> void:
	if not music_player:
		return
	music_player.volume_db = linear_to_db(maxf(music_volume, 0.0001))
	music_player.volume_db = -80.0 if music_volume <= 0.0 else music_player.volume_db

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Unable to save audio settings: %s" % error)
