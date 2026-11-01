// Linha pintada/riscada no asfalto, gasta e falhada.
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 paint_color : source_color = vec3(0.86, 0.85, 0.80);
uniform float wear : hint_range(0.0, 1.0) = 0.33;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise3(world_pos * 7.0) * 0.55 + noise3(world_pos * 1.2) * 0.45;
	if (n < wear) {
		discard;
	}
	ALBEDO = paint_color * (0.82 + 0.18 * n);
	ROUGHNESS = 0.85;
}
