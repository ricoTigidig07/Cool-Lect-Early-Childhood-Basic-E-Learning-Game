shader_type canvas_item;

// Lily pads gently float on the water: a slow bob up and down with a tiny drift.

uniform float bob_amount = 0.6;   // pixels
uniform float drift_amount = 0.35;
uniform float bob_speed = 1.1;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float p = (world.x + world.y) * 0.012;
	VERTEX.y += sin(TIME * bob_speed + p) * bob_amount;
	VERTEX.x += sin(TIME * bob_speed * 0.6 + p * 1.7) * drift_amount;
}
