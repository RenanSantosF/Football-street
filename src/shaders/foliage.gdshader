// Folhagem leve: "nuvens" de folhas recortadas por ruído (alpha scissor),
// com variação de verde e luz atravessando. Barato para celular.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 leaf_a : source_color = vec3(0.17, 0.30, 0.10);
uniform vec3 leaf_b : source_color = vec3(0.30, 0.42, 0.14);
uniform float cutout : hint_range(0.0, 1.0) = 0.45;
uniform float leaf_scale = 9.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// balanço leve com o vento
	VERTEX.x += sin(TIME * 1.3 + world_pos.x * 0.7 + world_pos.y) * 0.02;
}

void fragment() {
	float n = noise3(world_pos * leaf_scale);
	float n2 = noise3(world_pos * leaf_scale * 2.3 + vec3(5.0));
	float a = n * 0.65 + n2 * 0.35;
	if (a < cutout) {
		discard;
	}
	ALBEDO = mix(leaf_a, leaf_b, smoothstep(0.4, 0.9, n2)) * (0.8 + 0.4 * n);
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
