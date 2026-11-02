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
// The player's feet and how fast they walk (0..1), set by the player every frame.
// A plant the player walks through shakes and leans away from them.
global uniform vec2 player_pos;
global uniform float player_speed;
uniform float rustle_amount = 1.8;

void vertex() {
	float py = UV.y / TEXTURE_PIXEL_SIZE.y;
	if (mod(py, padded_tile) < padded_tile * 0.5) {
		vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		float gust = 0.7 + 0.3 * sin(TIME * 0.4 + world.x * 0.005);
		VERTEX.x += sin(TIME * sway_speed - world.x * wave_scale + world.y * 0.21) * sway_amount * gust;
		// middle of this plant's tile (this corner is on the left or the right side of it)
		float px = UV.x / TEXTURE_PIXEL_SIZE.x;
		vec2 mid = world + vec2(mod(px, padded_tile) < padded_tile * 0.5 ? 8.0 : -8.0, 10.0);
		float near = 1.0 - smoothstep(4.0, 15.0, distance(mid, player_pos));
		float r = near * player_speed;
		VERTEX.x += (sin(TIME * 32.0 + mid.x) * 1.2 + sign(mid.x - player_pos.x + 0.01) * 1.0) * r * rustle_amount;
	}
}
