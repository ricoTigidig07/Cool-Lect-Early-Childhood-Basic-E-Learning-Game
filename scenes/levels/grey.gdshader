shader_type canvas_item;
// Turns a locked island grey.
uniform float amount : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g * 0.85 + 0.2), amount), c.a);
}
