shader_type canvas_item;

// Darkens the whole screen except a rounded box (the thing to press).
uniform vec2 rect_size = vec2(1280.0, 720.0);   // size of the ColorRect (screen)
uniform vec4 hole = vec4(0.0);                  // x, y, width, height of the bright box
uniform float radius = 18.0;
uniform float soft = 8.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 half_size = hole.zw * 0.5;
	vec2 q = abs(p - (hole.xy + half_size)) - half_size + vec2(radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(0.0, 0.0, 0.0, dim * smoothstep(0.0, soft, d));
}
