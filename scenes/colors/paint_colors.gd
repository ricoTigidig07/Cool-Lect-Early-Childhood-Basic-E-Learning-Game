class_name PaintColors
extends RefCounted

## Every paint color in the game, and which two colors mix into a new one.

const COLORS := {
	"red": Color(0.86, 0.24, 0.24),
	"orange": Color(0.96, 0.55, 0.16),
	"yellow": Color(0.98, 0.83, 0.24),
	"green": Color(0.33, 0.68, 0.29),
	"blue": Color(0.27, 0.48, 0.87),
	"purple": Color(0.56, 0.33, 0.76),
	"pink": Color(0.96, 0.56, 0.72),
	"brown": Color(0.55, 0.35, 0.2),
	"black": Color(0.22, 0.22, 0.26),
	"white": Color(0.98, 0.98, 0.98),
	"grey": Color(0.6, 0.62, 0.66),
}

## color = first + second (order doesn't matter)
const RECIPES := {
	"orange": ["red", "yellow"],
	"green": ["blue", "yellow"],
	"purple": ["red", "blue"],
	"pink": ["red", "white"],
	"grey": ["black", "white"],
	"brown": ["red", "green"],
}

const BUCKET_BASE := preload("res://assets/colors/bucket_base.png")
const BUCKET_PAINT := preload("res://assets/colors/bucket_paint.png")

static func color(name: String) -> Color:
	return COLORS.get(name, Color.WHITE)

static func is_paint(name: String) -> bool:
	return COLORS.has(name)

## The color you get by mixing a and b, or "" if they don't mix.
static func mix(a: String, b: String) -> String:
	for result in RECIPES.keys():
		var r: Array = RECIPES[result]
		if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
			return result
	return ""

## A bucket picture in this color, for the hotbar.
static func bucket_icon(name: String) -> Texture2D:
	var img: Image = BUCKET_BASE.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var paint: Image = BUCKET_PAINT.get_image()
	paint.convert(Image.FORMAT_RGBA8)
	var tint := color(name)
	for y in paint.get_height():
		for x in paint.get_width():
			var p := paint.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, Color(p.r * tint.r, p.g * tint.g, p.b * tint.b, 1.0))
	return ImageTexture.create_from_image(img)

## Makes the hotbar show this paint's bucket.
static func register_icon(name: String) -> void:
	var hotbar = GameUIManager.hotbar
	if hotbar and not hotbar.item_icons.has(name):
		hotbar.item_icons[name] = bucket_icon(name)
