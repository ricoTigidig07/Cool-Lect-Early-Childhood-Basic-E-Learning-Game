shader_type canvas_item;

// Joyful gameplay light, drawn over the world but under the GameUI.
//  - brighter, more colorful picture (saturation / brightness / a touch of warmth)
//  - soft sun rays from the top-left corner that slowly shimmer
//  - fluffy cloud shadows that drift across the ground (they stay on the ground when the camera moves)
//  - a very light warm edge so the eye goes to the middle

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

group_uniforms picture;
uniform float saturation : hint_range(0.5, 2.0) = 1.25; // vibrance: boosts dull colors more than already-bright ones
uniform float brightness : hint_range(0.5, 1.5) = 1.03;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
uniform vec3 warmth = vec3(1.02, 1.0, 0.98);

group_uniforms sun_rays;
uniform vec4 ray_color : source_color = vec4(1.0, 0.96, 0.75, 1.0);
uniform float ray_strength : hint_range(0.0, 0.5) = 0.11;

group_uniforms clouds;
uniform float cloud_strength : hint_range(0.0, 0.5) = 0.10;
uniform float cloud_scale = 0.006;
uniform vec2 cloud_speed = vec2(7.0, 2.5);  // world pixels per second
uniform vec2 view_origin = vec2(0.0);       // set by player.gd every frame
uniform vec2 view_size = vec2(346.0, 195.0); // set by player.gd every frame

group_uniforms edges;
uniform vec4 edge_color : source_color = vec4(0.45, 0.25, 0.15, 1.0);
uniform float edge_strength : hint_range(0.0, 1.0) = 0.14;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15;
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// colorful, bright picture
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(l), c, 1.0 + (saturation - 1.0) * (1.0 - sat));
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness * warmth;

	// cloud shadows (in world space)
	vec2 w = view_origin + SCREEN_UV * view_size;
	float n = fbm((w - TIME * cloud_speed) * cloud_scale);
	c *= 1.0 - smoothstep(0.55, 0.78, n) * cloud_strength;

	// sun rays from the top-left
	vec2 uv = SCREEN_UV;
	float across = uv.x * 1.2 - uv.y;
	float rays = (sin(across * 16.0 + sin(TIME * 0.35) * 1.2) * 0.5 + 0.5)
			* (sin(across * 6.0 - TIME * 0.25) * 0.5 + 0.5);
	float near_sun = clamp(1.0 - length(uv * vec2(1.0, 1.3)) * 0.85, 0.0, 1.0);
	c += ray_color.rgb * rays * near_sun * ray_strength;
	c += ray_color.rgb * near_sun * near_sun * ray_strength * 0.35; // soft sun glow

	// light warm edges
	float d = length((uv - 0.5) * vec2(1.4, 1.0));
	c = mix(c, edge_color.rgb, smoothstep(0.5, 1.0, d) * edge_strength);

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
