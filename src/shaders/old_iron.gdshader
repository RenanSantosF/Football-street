// Ferro velho pintado: tinta branca descascada com ferrugem aparecendo.
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 paint_color : source_color = vec3(0.80, 0.79, 0.74);
uniform vec3 rust_color : source_color = vec3(0.36, 0.20, 0.11);
uniform vec3 metal_color : source_color = vec3(0.22, 0.21, 0.20);
uniform float rust_amount : hint_range(0.0, 1.0) = 0.45;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = fbm3(world_pos * 9.0);
	float big = noise3(world_pos * 1.7);
	float rust = smoothstep(1.0 - rust_amount, 1.05 - rust_amount * 0.6, n * 0.7 + big * 0.5);
	float bare = smoothstep(0.75, 0.9, noise3(world_pos * 23.0)) * rust;
	vec3 col = mix(paint_color * (0.9 + 0.1 * big), rust_color * (0.8 + 0.4 * n), rust);
	col = mix(col, metal_color, bare);
	ALBEDO = col;
	METALLIC = mix(0.0, 0.7, bare);
	ROUGHNESS = mix(0.55, 0.9, rust);
}
