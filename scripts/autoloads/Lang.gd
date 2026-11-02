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

const ITEM_NAMES := preload("res://scripts/lang/item_names.gd")
## Who says the item names in each subject (the subject's NPC).
const ITEM_VOICE := {"fruits": "merchant", "animals": "farmer", "alphabets": "teacher",
		"numbers": "grandma", "shapes": "builder", "colors": "painter"}
const ITEM_REPEAT_MS := 2500     # the same item is not said again within this time

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

# ---------- item names ----------

var _item_voice: AudioStreamPlayer
var _item_said := {}      # item key -> time it was last said

## An item's name ("Apple", "Capital A", "Red paint") in the chosen language.
func item_name(english: String) -> String:
	if code == "en" or not ITEM_NAMES.NAMES.has(english):
		return english
	return ITEM_NAMES.NAMES[english][1 if code == "ceb" else 0]

## "Apple" -> apple, "Capital A" / "Small a" -> letter_a, "Red paint" -> paint_red
func item_key(english: String) -> String:
	if english.begins_with("Capital ") or english.begins_with("Small "):
		return "letter_" + english.right(1).to_lower()
	if english.ends_with(" paint"):
		return "paint_" + english.get_slice(" ", 0).to_lower()
	return english.to_lower().replace(" ", "_")

## Lola Nena says a number (1-10) in the chosen language (assets/audio/voice*/grandma/item_num_<n>.ogg).
## again = true: say it even if it was just said (counting eggs).
func say_number(n: int, again := false) -> void:
	if n < 1 or n > 10:
		return
	if not again and (GameUIManager.talking or (GameUIManager.dialogue_panel and \
			is_instance_valid(GameUIManager.dialogue_panel) and GameUIManager.dialogue_panel.visible)):
		return
	var path := "%sgrandma/item_num_%d.ogg" % [voice_dir(), n]
	var now := Time.get_ticks_msec()
	if not again and now - int(_item_said.get(path, -100000)) < ITEM_REPEAT_MS:
		return
	if not ResourceLoader.exists(path):
		return
	_item_said[path] = now
	_play_item(path)

## A few words on screen (not dialogue) in the chosen language.
const WORDS := {"Too many!": ["Sobra na!", "Sobra na!"]}
func word(english: String) -> String:
	if code == "en" or not WORDS.has(english):
		return english
	return WORDS[english][1 if code == "ceb" else 0]

## The subject's NPC says the item's name (cut from their voice-over), in the chosen language.
## Clips: assets/audio/voice*/<npc>/item_<key>.ogg
func say_item(english: String) -> void:
	if GameUIManager.talking or (GameUIManager.dialogue_panel and is_instance_valid(GameUIManager.dialogue_panel) \
			and GameUIManager.dialogue_panel.visible):
		return
	var npc: String = ITEM_VOICE.get(GameManager.current_subject, "")
	if npc == "":
		return
	var path := "%s%s/item_%s.ogg" % [voice_dir(), npc, item_key(english)]
	var now := Time.get_ticks_msec()
	if now - int(_item_said.get(path, -100000)) < ITEM_REPEAT_MS:
		return
	if not ResourceLoader.exists(path):
		return
	_item_said[path] = now
	_play_item(path)

func _play_item(path: String) -> void:
	if _item_voice == null:
		_item_voice = AudioStreamPlayer.new()
		_item_voice.bus = &"SFX"
		add_child(_item_voice)
	_item_voice.stream = load(path)
	_item_voice.play()
