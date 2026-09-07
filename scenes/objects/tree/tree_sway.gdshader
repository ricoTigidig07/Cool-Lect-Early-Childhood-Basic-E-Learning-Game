shader_type canvas_item;

uniform float shake_intensity = 1.5;
uniform float shake_speed = 3.0;
uniform float log_height = 1.5; // vertices below this stay still, fades in above it
uniform float falloff_sharpness = 2.0;

void vertex() {
	vec2 shake = vec2(0.0);
	
	float factor = clamp(1.0 - (VERTEX.y / log_height), 0.0, 1.0);
	factor = pow(factor, falloff_sharpness);
	
	shake.x = sin(TIME * shake_speed + VERTEX.y) * shake_intensity * factor;
	
	VERTEX.xy += shake;
}