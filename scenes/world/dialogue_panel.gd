extends TextureRect

## Dialogue box: portrait of whoever is talking, their name, typewriter text,
## a bouncing "continue" arrow, and Yes/No choice buttons.
## Tap/click anywhere on the box to finish typing or go to the next page.
## Public API is unchanged: set_text(), show_pages(), show_choices(),
## signals finished / choice_selected / skipped / advanced.

@onready var label: Label = $Label
@onready var name_label: Label = $NameLabel
@onready var portrait: TextureRect = $Portrait
@onready var continue_icon: TextureRect = $ContinueIcon
@onready var choices_container: VBoxContainer = $ChoicesContainer
@onready var yes_button: Button = $ChoicesContainer/YesButton
@onready var no_button: Button = $ChoicesContainer/NoButton
@onready var voice: AudioStreamPlayer = $Voice

## Voice clips: assets/audio/voice/<speaker voice_id>/<md5 of the line>.ogg
## (made by tools/make_voices.py). A line without a clip just types with the blips.
const VOICE_DIR := "res://assets/audio/voice/"
var voice_id := ""

const CHARS_PER_SECOND = 35.0
const MIN_FONT_SIZE = 30
const MAX_FONT_SIZE = 46
const CONTINUE_FRAMES = 7
const CONTINUE_FPS = 10.0
const TAP_GUARD_MS = 250

var typing_timer: Timer
var full_text: String = ""
var pages: Array[String] = []
var current_page: int = 0
var base_position: Vector2
var continue_time: float = 0.0
var continue_atlas: AtlasTexture
var last_tap_ms: int = 0

signal skipped
signal advanced
signal finished
signal choice_selected(choice_text: String)

func _ready() -> void:
	typing_timer = Timer.new()
	typing_timer.wait_time = 1.0 / CHARS_PER_SECOND
	typing_timer.timeout.connect(_on_typing_tick)
	add_child(typing_timer)

	yes_button.pressed.connect(_on_choice_pressed.bind(yes_button))
	no_button.pressed.connect(_on_choice_pressed.bind(no_button))
	gui_input.connect(_on_gui_input)
	visibility_changed.connect(_on_visibility_changed)

	continue_atlas = continue_icon.texture as AtlasTexture
	choices_container.visible = false
	continue_icon.visible = false
	base_position = position

func _process(delta: float) -> void:
	if continue_icon.visible and continue_atlas:
		continue_time += delta
		var frame := int(continue_time * CONTINUE_FPS) % CONTINUE_FRAMES
		continue_atlas.region.position.x = frame * 16 + 3

# ---------- showing text ----------

func set_text(text: String) -> void:
	show_pages([text])

func show_pages(new_pages: Array[String]) -> void:
	pages = new_pages
	current_page = 0
	_detect_speaker()
	_show_current_page()

func _show_current_page() -> void:
	full_text = pages[current_page]
	_apply_responsive_font_size(full_text)
	label.text = full_text
	label.visible_characters = 0
	_play_voice(full_text)
	last_tap_ms = Time.get_ticks_msec()   # a new page ignores the tap that opened it
	choices_container.visible = false
	continue_icon.visible = false
	typing_timer.start()

func _play_voice(text: String) -> void:
	voice.stop()
	if voice_id == "":
		return
	var path := "%s%s/%s.ogg" % [VOICE_DIR, voice_id, text.md5_text()]
	if ResourceLoader.exists(path):
		voice.stream = load(path)
		voice.play()

func _apply_responsive_font_size(text: String) -> void:
	var font = label.get_theme_font("font")
	if label.label_settings and label.label_settings.font:
		font = label.label_settings.font
	if font == null:
		font = ThemeDB.fallback_font
	var best_size = MIN_FONT_SIZE
	for font_size in range(MAX_FONT_SIZE, MIN_FONT_SIZE - 1, -2):
		var wrapped = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, font_size)
		if wrapped.y <= label.size.y:
			best_size = font_size
			break
	if label.label_settings:
		label.label_settings.font_size = best_size
	else:
		label.add_theme_font_size_override("font_size", best_size)

func _on_typing_tick() -> void:
	label.visible_characters += 1
	# soft talking blips (every 3rd letter, not on spaces)
	var i: int = label.visible_characters - 1
	if i % 3 == 0 and i < full_text.length() and full_text[i] != " " and not voice.playing:
		AudioManager.play_sfx("blip", randf_range(0.92, 1.12))
	if label.visible_characters >= full_text.length():
		typing_timer.stop()
		_on_page_typing_finished()

func _on_page_typing_finished() -> void:
	var is_last_page = current_page >= pages.size() - 1
	if is_last_page:
		continue_icon.visible = false
		finished.emit()
	else:
		continue_time = 0.0
		continue_icon.visible = true

# ---------- speaker ----------

func _detect_speaker() -> void:
	var speaker: Node = GameUIManager.talk_speaker if GameUIManager.talk_speaker else InteractionManager.get_current_target()
	if speaker and speaker.name == "InteractionArea":
		speaker = speaker.get_parent()
	voice_id = ""
	if speaker != null and "voice_id" in speaker:
		voice_id = speaker.voice_id
	if speaker == null:
		name_label.text = ""
		portrait.texture = null
		return

	if "display_name" in speaker and speaker.display_name != "":
		name_label.text = speaker.display_name
	else:
		name_label.text = String(speaker.name)

	portrait.texture = null
	portrait.self_modulate = Color.WHITE
	for child in speaker.get_children():
		if child is AnimatedSprite2D and child.sprite_frames:
			var anim: StringName = &"idle_front" if child.sprite_frames.has_animation(&"idle_front") else child.animation
			portrait.texture = _crop_to_character(child.sprite_frames.get_frame_texture(anim, 0))
			portrait.self_modulate = child.modulate
			break

## Character frames are 48x48 with a small character in the middle.
## Zoom in on the middle so the face fills the portrait frame.
func _crop_to_character(tex: Texture2D) -> Texture2D:
	if tex is AtlasTexture:
		var src := tex as AtlasTexture
		var crop := AtlasTexture.new()
		crop.atlas = src.atlas
		var r := src.region
		crop.region = Rect2(r.position + r.size * Vector2(0.3, 0.3), r.size * Vector2(0.4, 0.4))
		# zoom on the head: a square at the top of the visible character, centred on
		# the middle of its pixels (so a pointer or a paint roller doesn't pull it sideways)
		var img := src.atlas.get_image() if src.atlas else null
		if img and not img.is_empty():
			var frame := img.get_region(Rect2i(r))
			var used := frame.get_used_rect()
			if used.size.y > 0:
				var side: float = max(8.0, used.size.y * 0.6)
				var xs: Array[int] = []
				for y in range(used.position.y, used.position.y + int(side)):
					for x in range(used.position.x, used.end.x):
						if frame.get_pixel(x, y).a > 0.5:
							xs.append(x)
				xs.sort()
				var center_x: float = xs[xs.size() / 2] if xs.size() > 0 else used.position.x + used.size.x / 2.0
				crop.region = Rect2(r.position.x + center_x + 0.5 - side / 2.0, r.position.y + used.position.y - 1, side, side)
		return crop
	return tex

# ---------- input ----------

func _on_gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped and not choices_container.visible:
		accept_event()
		# On phones one tap arrives twice (touch + the copied mouse click),
		# and the tap that opened the box can land on it too: ignore repeats.
		var now := Time.get_ticks_msec()
		if now - last_tap_ms < TAP_GUARD_MS:
			return
		last_tap_ms = now
		_advance()

func _advance() -> void:
	if label.visible_characters != -1 and label.visible_characters < full_text.length():
		label.visible_characters = -1
		typing_timer.stop()
		_on_page_typing_finished()
		skipped.emit()
		return
	if current_page < pages.size() - 1:
		current_page += 1
		_show_current_page()
		advanced.emit()

# kept so old callers still work
func _on_next_pressed() -> void:
	_advance()

func _on_skip_pressed() -> void:
	_advance()

# ---------- choices ----------

func show_choices(choices: Array[String]) -> void:
	if choices.size() >= 1:
		yes_button.text = choices[0]
	if choices.size() >= 2:
		no_button.text = choices[1]
	continue_icon.visible = false
	choices_container.visible = true
	choices_container.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(choices_container, "modulate:a", 1.0, 0.15)

func _on_choice_pressed(button: Button) -> void:
	choices_container.visible = false
	choice_selected.emit(button.text)

# ---------- pop-in ----------

func _on_visibility_changed() -> void:
	AudioManager.duck_music(visible)       # music quieter while someone talks
	if visible:
		position = base_position + Vector2(0, 30)
		modulate.a = 0.0
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "position", base_position, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "modulate:a", 1.0, 0.12)
	else:
		typing_timer.stop()
		voice.stop()
		choices_container.visible = false
		continue_icon.visible = false
