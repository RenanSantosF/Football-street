// Madeira velha de cerca: tábuas acinzentadas pelo sol e chuva, com veios,
// nós escuros, partes mais claras e base suja de barro.
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 wood_light : source_color = vec3(0.55, 0.50, 0.43);
uniform vec3 wood_dark : source_color = vec3(0.30, 0.25, 0.20);
uniform vec3 mud : source_color = vec3(0.28, 0.21, 0.14);
uniform float seed = 0.0;

varying vec3 world_pos;
varying vec3 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
}

void fragment() {
	// Veios ao longo da tábua (eixo Y local).
	float grain = noise3(vec3(local_pos.x * 40.0, local_pos.y * 2.0, local_pos.z * 40.0) + seed);
	float streak = noise3(vec3(world_pos.x * 6.0 + seed, world_pos.y * 0.6, world_pos.z * 6.0));
	vec3 col = mix(wood_dark, wood_light, smoothstep(0.25, 0.8, grain * 0.6 + streak * 0.5));
	float knot = smoothstep(0.82, 0.9, noise3(world_pos * 7.0 + seed * 3.0));
	col = mix(col, wood_dark * 0.6, knot);
	float base = 1.0 - smoothstep(0.0, 0.45, world_pos.y);
	col = mix(col, mud, base * 0.7 * (0.6 + 0.4 * noise3(world_pos * 5.0)));
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
