extends Node

## The game's language: English, Tagalog or Cebuano (Bisaya).
## Only the NPC dialogue (and its Yes / No answers) and the NPC voices change.
##   Lang.line(english)  -> the line in the chosen language (English if not translated)
##   Lang.voice_dir()    -> where the voice clips for the chosen language are
## The translations are in scripts/lang/dialogue_tl.gd and dialogue_ceb.gd.
## Voice clips: assets/audio/voice/ (English), voice_tl/ (Tagalog), voice_ceb/ (Cebuano),
## each one named after the English line (<voice_id>/<md5 of the English line>.ogg).

signal changed

const SAVE_PATH := "user://language.cfg"
const CODES := ["en", "tl", "ceb"]
const NAMES := {"en": "English", "tl": "Tagalog", "ceb": "Bisaya"}
const VOICE_DIRS := {"en": "res://assets/audio/voice/", "tl": "res://assets/audio/voice_tl/",
		"ceb": "res://assets/audio/voice_ceb/"}
const TABLES := {
	"tl": preload("res://scripts/lang/dialogue_tl.gd"),
	"ceb": preload("res://scripts/lang/dialogue_ceb.gd"),
}

var code := "en"
## True once a language was picked (a new player picks it on the first screen).
var chosen := false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var c: String = cfg.get_value("language", "code", "en")
		code = c if c in CODES else "en"
		chosen = true

func set_language(new_code: String) -> void:
	if not new_code in CODES:
		return
	code = new_code
	chosen = true
	var cfg := ConfigFile.new()
	cfg.set_value("language", "code", code)
	cfg.save(SAVE_PATH)
	changed.emit()

## Next language in the list (for the settings button).
func next_code() -> String:
	return CODES[(CODES.find(code) + 1) % CODES.size()]

func display_name(c: String = "") -> String:
	return NAMES.get(c if c != "" else code, "English")

## One dialogue line in the chosen language.
func line(english: String) -> String:
	if code == "en":
		return english
	var key := english.strip_edges()
	var lines: Dictionary = TABLES[code].LINES
	if lines.has(key):
		return lines[key]
	return english

func voice_dir() -> String:
	return VOICE_DIRS[code]
