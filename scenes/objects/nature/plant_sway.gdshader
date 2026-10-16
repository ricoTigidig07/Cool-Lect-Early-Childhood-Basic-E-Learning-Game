shader_type canvas_item;

// Light wind for plant tiles (grass, flowers, mushrooms, reeds, crops).
// The bottom of the tile stays planted; only the top edge leans left and right,
// and the wind rolls across the map as a soft wave. Nothing is moved for real.

uniform float sway_amount = 0.8;  // pixels the top edge leans
uniform float sway_speed = 1.5;
uniform float wave_scale = 0.025; // how wide the wind wave is across the map
// Godot draws tiles from a padded copy of the sheet (16 px tile + 1 px on each side = 18),
// so every tile's top edge sits near the start of an 18 px step.
uniform float padded_tile = 18.0;

void vertex() {
	float py = UV.y / TEXTURE_PIXEL_SIZE.y;
	if (mod(py, padded_tile) < padded_tile * 0.5) {
		vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		float gust = 0.7 + 0.3 * sin(TIME * 0.4 + world.x * 0.005);
		VERTEX.x += sin(TIME * sway_speed - world.x * wave_scale + world.y * 0.21) * sway_amount * gust;
	}
}
