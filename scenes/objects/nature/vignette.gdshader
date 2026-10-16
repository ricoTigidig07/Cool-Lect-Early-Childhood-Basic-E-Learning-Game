shader_type canvas_item;

// Soft, warm darkening around the screen edges so the eye goes to the middle.
// Sits on its own CanvasLayer under the GameUI, so buttons and dialogue are not covered.

uniform vec4 edge_color : source_color = vec4(0.25, 0.15, 0.1, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.22;
uniform float size : hint_range(0.0, 1.0) = 0.45;
uniform float softness : hint_range(0.05, 1.0) = 0.5;

void fragment() {
	float d = length((UV - 0.5) * vec2(1.4, 1.0));
	float v = smoothstep(size, size + softness, d);
	COLOR = vec4(edge_color.rgb, v * strength);
}
