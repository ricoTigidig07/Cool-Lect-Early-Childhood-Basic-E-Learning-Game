extends Node

## Plays the background music (BGM) and the sound effects (SFX) for the whole game.
##
## Music changes by itself when the scene changes:
##   menus (main menu, profile, new player ...)  -> menu.ogg
##   level select islands (*_level_select.tscn)  -> level_map.ogg
##   inside a level (scenes/levels/...)          -> gameplay.ogg
##
## Any script can play a sound effect:
##   AudioManager.play_sfx("collect")
##   AudioManager.play_sfx("place", 1.2)        # higher pitch
## Every Button in the game makes a click sound automatically.
## Volumes: open the Audio panel at the bottom of the editor (Music and SFX buses).

const MUSIC := {
	"menu": preload("res://assets/audio/bgm/menu.ogg"),
	"level_map": preload("res://assets/audio/bgm/level_map.ogg"),
	"gameplay": preload("res://assets/audio/bgm/gameplay.ogg"),
}
const JINGLE := preload("res://assets/audio/bgm/level_complete.ogg")
const SFX := {
	"ui_click": preload("res://assets/audio/sfx/ui_click.wav"),
	"pop": preload("res://assets/audio/sfx/pop.wav"),
	"collect": preload("res://assets/audio/sfx/collect.wav"),
	"place": preload("res://assets/audio/sfx/place.wav"),
	"wrong": preload("res://assets/audio/sfx/wrong.wav"),
	"blip": preload("res://assets/audio/sfx/blip.wav"),
	"mission": preload("res://assets/audio/sfx/mission.wav"),
	"star": preload("res://assets/audio/sfx/star.wav"),
	"mix": preload("res://assets/audio/sfx/mix.wav"),
	"paint": preload("res://assets/audio/sfx/paint.wav"),
	"hop": preload("res://assets/audio/sfx/hop.wav"),
}
## Extra loudness per sound (dB), so quiet/loud ones sit nicely together.
const SFX_VOLUME := {"ui_click": -4.0, "blip": -10.0, "hop": -8.0, "pop": -3.0, "paint": -2.0}

const SETTINGS_PATH := "user://audio.cfg"
const MUSIC_DB := 0.0
const FADE_TIME := 0.8
const SFX_VOICES := 8

var music_on := true
var sfx_on := true

var _music_players: Array[AudioStreamPlayer] = []
var _active := 0
var _current_track := ""
var _jingle_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_scene: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # music keeps playing in the pause menu
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music_players.append(p)
	_jingle_player = AudioStreamPlayer.new()
	_jingle_player.bus = "Music"
	add_child(_jingle_player)
	for i in SFX_VOICES:
		var s := AudioStreamPlayer.new()
		s.bus = "SFX"
		add_child(s)
		_sfx_players.append(s)
	for key in MUSIC:
		MUSIC[key].loop = true
	_load_settings()
	get_tree().node_added.connect(_on_node_added)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		if scene:
			play_music(_track_for(scene.scene_file_path))

# ---------- music ----------

func _track_for(path: String) -> String:
	if path.contains("/levels/"):
		return "level_map" if path.contains("level_select") else "gameplay"
	return "menu"

## Cross-fades to another song ("menu", "level_map", "gameplay").
func play_music(track: String) -> void:
	if track == _current_track or not MUSIC.has(track):
		return
	_current_track = track
	var outgoing := _music_players[_active]
	_active = 1 - _active
	var incoming := _music_players[_active]
	incoming.stream = MUSIC[track]
	incoming.volume_db = -40.0
	incoming.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(incoming, "volume_db", MUSIC_DB, FADE_TIME)
	t.tween_property(outgoing, "volume_db", -60.0, FADE_TIME)
	t.chain().tween_callback(outgoing.stop)

## The "level complete" tune. The music goes quiet while it plays.
func play_level_complete() -> void:
	var music := _music_players[_active]
	var t := create_tween()
	t.tween_property(music, "volume_db", -18.0, 0.25)
	_jingle_player.stream = JINGLE
	_jingle_player.play()
	t.tween_interval(JINGLE.get_length())
	t.tween_property(music, "volume_db", MUSIC_DB, 1.2)

# ---------- sound effects ----------

func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not sfx_on or not SFX.has(sfx_name):
		return
	var p := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	p.stream = SFX[sfx_name]
	p.pitch_scale = pitch
	p.volume_db = SFX_VOLUME.get(sfx_name, 0.0)
	p.play()

## Every Button (and TextureButton) clicks when pressed.
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("no_click_sound"):
		if node.get_parent() and node.get_parent().name == "InteractionButton":
			return   # the big hold button: the actions make their own sounds
		node.pressed.connect(play_sfx.bind("ui_click"))

# ---------- on / off (saved) ----------

func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	_save_settings()

func set_sfx_on(on: bool) -> void:
	sfx_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not on)
	_save_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = cfg.get_value("audio", "music_on", true)
		sfx_on = cfg.get_value("audio", "sfx_on", true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.save(SETTINGS_PATH)

## Makes the Music / SFX bus if default_bus_layout.tres doesn't have it.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
