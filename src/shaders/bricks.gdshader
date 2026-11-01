// Tijolo baiano/maciço aparente com argamassa escorrida (obra sem reboco).
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 brick_a : source_color = vec3(0.62, 0.33, 0.22);
uniform vec3 brick_b : source_color = vec3(0.52, 0.27, 0.18);
uniform vec3 mortar : source_color = vec3(0.62, 0.60, 0.56);
uniform vec2 brick_size = vec2(0.24, 0.12);

varying vec3 world_pos;
varying vec3 wnormal;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Coordenada ao longo da parede (x ou z, conforme a face) e altura.
	float u = abs(wnormal.x) > abs(wnormal.z) ? world_pos.z : world_pos.x;
	vec2 p = vec2(u, world_pos.y);
	float row = floor(p.y / brick_size.y);
	vec2 q = vec2(p.x / brick_size.x + mod(row, 2.0) * 0.5, p.y / brick_size.y);
	vec2 cell = floor(q);
	vec2 f = fract(q);
	vec2 e = min(f, 1.0 - f) * brick_size;
	float m = 1.0 - smoothstep(0.006, 0.012, min(e.x, e.y));
	float r = h2(cell);
	vec3 col = mix(brick_a, brick_b, r) * (0.85 + 0.25 * noise3(world_pos * 30.0));
	float smear = smoothstep(0.6, 0.85, noise3(world_pos * 3.0));
	col = mix(col, mortar * 0.9, smear * 0.35);
	col = mix(col, mortar * (0.85 + 0.2 * noise3(world_pos * 40.0)), m);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
