// Pele + roupa do personagem humanoide.
// As máscaras de roupa vêm das cores de vértice (ClothingMeshBaker):
//   R camiseta, G bermuda, B tênis, A meia.
// A textura do modelo base vira só "detalhe" (luminância) multiplicado pela
// cor de pele escolhida: um único conjunto de texturas serve para todos os
// tons de pele. O relevo muscular do normal map é atenuado (corpo juvenil).
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_avg = 0.42;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.3;
uniform float muscle_definition : hint_range(0.0, 1.0) = 0.12;

uniform vec3 skin_color : source_color = vec3(0.62, 0.43, 0.30);
uniform float has_shirt : hint_range(0.0, 1.0) = 1.0;
uniform vec3 shirt_color : source_color = vec3(0.85, 0.85, 0.82);
uniform vec3 shorts_color : source_color = vec3(0.15, 0.17, 0.25);
uniform vec3 shoes_color : source_color = vec3(0.9, 0.9, 0.88);
uniform vec3 socks_color : source_color = vec3(0.9, 0.9, 0.88);
uniform float dirt : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 0.0;

uniform float shirt_inflate = 0.007;
uniform float shorts_inflate = 0.022;
uniform float shoes_inflate = 0.02;


void vertex() {
	float inflate = max(max(COLOR.r * has_shirt * shirt_inflate, COLOR.g * shorts_inflate),
		max(COLOR.b * shoes_inflate, COLOR.a * 0.002));
	VERTEX += NORMAL * inflate;
}

void fragment() {
	vec3 tex = texture(detail_tex, UV).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	vec3 skin = skin_color * mix(1.0, clamp(lum / detail_avg, 0.6, 1.4), detail_strength);

	float shirt_m = smoothstep(0.35, 0.65, COLOR.r) * has_shirt;
	float shorts_m = smoothstep(0.35, 0.65, COLOR.g);
	float shoes_m = smoothstep(0.35, 0.65, COLOR.b);
	float socks_m = smoothstep(0.35, 0.65, COLOR.a);
	float cloth = max(max(shirt_m, shorts_m), max(shoes_m, socks_m));

	// Trama do tecido e sujeira (mais nas partes de baixo e nos tênis).
	vec3 q = vec3(UV * 90.0, seed);
	float weave = 0.93 + 0.07 * noise3(q);
	float dirt_n = smoothstep(0.45, 0.85, fbm3(vec3(UV * 9.0, seed * 3.1)));
	vec3 dirt_col = vec3(0.33, 0.27, 0.2);

	vec3 col = skin;
	col = mix(col, socks_color * weave, socks_m);
	col = mix(col, mix(shoes_color, dirt_col, dirt * 0.55) * weave, shoes_m);
	col = mix(col, shorts_color * weave, shorts_m);
	col = mix(col, shirt_color * weave, shirt_m);
	float dirt_amount = dirt * dirt_n * (cloth > 0.5 ? 0.6 : 0.25);
	col = mix(col, dirt_col, dirt_amount);

	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.92, cloth);
	SPECULAR = mix(0.4, 0.15, cloth);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = mix(muscle_definition, 0.1, cloth);
}
