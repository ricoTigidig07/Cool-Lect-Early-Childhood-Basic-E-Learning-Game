extends Area2D

@export var target_letter: String = "A"
@export var letter_sequence: NodePath

@onready var sign_capital: TextureRect = $SignLetters/SignCapital
@onready var sign_small: TextureRect = $SignLetters/SignSmall
@onready var capital_icon: TextureRect = $PanelContainer/HBoxContainer/CapitalLetter/TextureRect
@onready var lowercase_icon: TextureRect = $PanelContainer/HBoxContainer/SmallLetter/TextureRect
@onready var hold_indicator: TextureProgressBar = $HoldIndicator

const HOLD_DURATION := 1.0
const LETTER_ICON_PATH := "res://scenes/collectables/alphabets/"

var placed_upper: bool = false
var placed_lower: bool = false
var is_holding: bool = false
var hold_progress: float = 0.0
var pending_letter: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false
	_reset_slots()

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)
		cancel_hold()

func start_hold() -> void:
	var equipped = GameUIManager.get_equipped_item()
	pending_letter = _needed_letter_for(equipped)
	if pending_letter == "":
		return
	is_holding = true
	hold_progress = 0.0
	hold_indicator.visible = true
	hold_indicator.value = 0

func cancel_hold() -> void:
	is_holding = false
	hold_progress = 0.0
	hold_indicator.visible = false

func _process(delta: float) -> void:
	if is_holding:
		hold_progress += delta / HOLD_DURATION
		hold_indicator.value = hold_progress * 100
		if hold_progress >= 1.0:
			_complete_hold()

func _complete_hold() -> void:
	is_holding = false
	hold_indicator.visible = false
	_place_letter(pending_letter)

func _needed_letter_for(equipped: String) -> String:
	if equipped == target_letter and not placed_upper:
		return target_letter
	if equipped == target_letter.to_lower() and not placed_lower:
		return target_letter.to_lower()
	return ""

func _place_letter(letter: String) -> void:
	GameUIManager.consume_hotbar_item(letter)
	var icon = _letter_icon(letter)
	if letter == target_letter:
		placed_upper = true
		capital_icon.texture = icon
	else:
		placed_lower = true
		lowercase_icon.texture = icon
	if placed_upper and placed_lower:
		_advance_letter()

func _advance_letter() -> void:
	var seq = get_node_or_null(letter_sequence)
	if seq:
		seq.advance()
		if seq.is_complete():
			GameUIManager.complete_mission_2()
			return
		target_letter = seq.current_letter()
	placed_upper = false
	placed_lower = false
	_reset_slots()

func _reset_slots() -> void:
	capital_icon.texture = null
	lowercase_icon.texture = null
	sign_capital.texture = _letter_icon(target_letter)
	sign_small.texture = _letter_icon(target_letter.to_lower())

func _letter_icon(letter: String) -> Texture2D:
	var prefix = "capital_" if letter == letter.to_upper() else "small_"
	return load(LETTER_ICON_PATH + prefix + letter + ".tres")
