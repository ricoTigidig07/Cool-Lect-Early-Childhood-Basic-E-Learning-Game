shader_type canvas_item;

// Bushes rustle a little in the wind. The base stays still, the top leans.
// Each bush uses its own position as the timing, so they don't all move together.

uniform float sway_amount = 0.7;  // pixels at the top of the bush
uniform float sway_speed = 1.3;
uniform float half_height = 8.0;  // half the sprite height (16 px bush = 8)

void vertex() {
	float f = clamp((half_height - VERTEX.y) / (2.0 * half_height), 0.0, 1.0);
	f = f * f;
	vec2 o = MODEL_MATRIX[3].xy;
	VERTEX.x += sin(TIME * sway_speed + o.x * 0.025 + o.y * 0.21) * sway_amount * f;
}
