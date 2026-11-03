shader_type canvas_item;

// Darkness over the places the player has not explored yet. Used three times:
//  - over the level itself (the game screen), over the small map and over the big map.
// "explored" is a small mask over the level: white = been there.
uniform sampler2D explored : filter_linear;
uniform sampler2D snapshot : filter_nearest;
uniform bool use_snapshot = false;   // big map: a still picture of the level shows faintly
uniform vec4 level_rect;             // x, y, w, h of the level (world)
uniform vec4 view_rect;              // x, y, w, h of the world shown under this rectangle
uniform float faint = 0.12;          // how much of the still picture shows through
uniform float max_dark = 1.0;        // how dark unexplored places get

void fragment() {
	vec2 world = view_rect.xy + UV * view_rect.zw;
	vec2 e_uv = (world - level_rect.xy) / level_rect.zw;
	float seen = 0.0;
	if (e_uv.x >= 0.0 && e_uv.y >= 0.0 && e_uv.x <= 1.0 && e_uv.y <= 1.0) {
		seen = texture(explored, e_uv).r;
	}
	seen = smoothstep(0.15, 0.85, seen);
	vec3 still = use_snapshot ? texture(snapshot, UV).rgb * faint : vec3(0.0);
	COLOR = vec4(still, (1.0 - seen) * max_dark);
}
