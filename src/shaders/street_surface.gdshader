// Superfície genérica de rua: asfalto, calçada, muro, reboco.
// Usa a posição no mundo (não precisa de UV) e só ruído procedural:
// variação de tom, manchas (óleo/umidade), rachaduras e granulado.
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.23, 0.23, 0.24);
uniform vec3 stain_color : source_color = vec3(0.13, 0.13, 0.13);
uniform vec3 crack_color : source_color = vec3(0.09, 0.09, 0.09);
uniform float variation : hint_range(0.0, 0.5) = 0.12;
uniform float noise_scale = 0.35;
uniform float stain_amount : hint_range(0.0, 1.0) = 0.5;
uniform float crack_amount : hint_range(0.0, 1.0) = 0.7;
uniform float crack_scale = 1.1;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.07;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.93;
uniform float dirt_bottom = 0.0; // escurece a base de paredes (sujeira de chuva)

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_pos;
	float low = fbm3(p * noise_scale);
	float grain = noise3(p * 19.0);
	vec3 col = base_color * (1.0 + (low - 0.5) * variation * 2.0 + (grain - 0.5) * grain_amount * 2.0);

	float stain = smoothstep(0.6, 0.85, fbm3(p * noise_scale * 0.45 + vec3(13.1, 3.3, 7.7)));
	col = mix(col, stain_color, stain * stain_amount);

	// Rachaduras: ruído "ridged" deformado, só em algumas regiões.
	float warp = noise3(p * 0.8) * 1.7;
	float r = noise3(p * crack_scale + vec3(warp));
	float ridge = 1.0 - abs(r * 2.0 - 1.0);
	float area = smoothstep(0.55, 0.75, noise3(p * 0.13 + vec3(5.0, 1.0, 9.0)));
	float crack = smoothstep(0.972, 0.993, ridge) * area * crack_amount * 0.85;
	col = mix(col, crack_color, crack);

	if (dirt_bottom > 0.0) {
		float d = 1.0 - smoothstep(0.0, 0.9, p.y);
		col *= 1.0 - d * dirt_bottom * (0.6 + 0.4 * low);
	}

	ALBEDO = col;
	ROUGHNESS = clamp(roughness_value - stain * 0.18, 0.0, 1.0);
	SPECULAR = 0.3;
}
