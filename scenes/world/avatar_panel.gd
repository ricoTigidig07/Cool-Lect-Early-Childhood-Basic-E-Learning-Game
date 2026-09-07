extends PanelContainer

var default_modulate = Color(1, 1, 1)
var highlight_modulate = Color(1, 0.85, 0.3)  # gold tint, adjust to taste

func set_highlighted(is_highlighted: bool) -> void:
	modulate = highlight_modulate if is_highlighted else default_modulate
