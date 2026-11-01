// Corpo base TEXTURIZADO (ex.: personagem gerado e rigado no Mixamo).
// A textura original é preservada; por cima:
//  - pele: pixels com a "cor" (crominância) da pele de referência são
//    recoloridos para o tom escolhido, mantendo luz/sombra/detalhes;
//  - cabelo: na cabeça, pixels escuros e pouco saturados recebem a cor do cabelo;
//  - roupa: máscaras de vértice (ClothingMeshBaker)
//      R camiseta, G bermuda, B tênis (1,0) / meia (0,5), A cabeça.
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 skin_ref : source_color = vec3(0.55, 0.36, 0.25);
uniform float skin_tolerance = 0.28;
uniform vec3 skin_color : source_color = vec3(0.55, 0.36, 0.25);
uniform vec3 hair_color : source_color = vec3(0.05, 0.04, 0.03);
uniform float hair_dark = 0.14;

uniform float has_shirt : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shirt_color : source_color = vec3(0.85, 0.85, 0.82);
// 0 = mantém a bermuda da textura, 1 = pinta com shorts_color
uniform float recolor_shorts : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shorts_color : source_color = vec3(0.15, 0.17, 0.25);
uniform float has_shoes : hint_range(0.0, 1.0) = 1.0;
uniform vec3 shoes_color : source_color = vec3(0.9, 0.9, 0.88);
uniform vec3 socks_color : source_color = vec3(0.9, 0.9, 0.88);
uniform float dirt : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 0.0;

uniform float shirt_inflate = 0.006;
uniform float shorts_inflate = 0.012;
uniform float shoes_inflate = 0.012;

void vertex() {
	float shoes_v = smoothstep(0.7, 0.9, COLOR.b) * has_shoes;
	float inflate = max(max(COLOR.r * has_shirt * shirt_inflate, COLOR.g * recolor_shorts * shorts_inflate),
		shoes_v * shoes_inflate);
	VERTEX += NORMAL * inflate;
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	float mx = max(tex.r, max(tex.g, tex.b));
	float sat = (mx - min(tex.r, min(tex.g, tex.b))) / max(mx, 0.001);

	// Pele: compara a crominância (cor sem o brilho) com a pele de referência.
	// Faixa larga: cobre as variações de tom da própria pele, mas exclui jeans
	// (azul), olhos (cinza) e manchas vermelhas da roupa.
	vec3 tn = tex / max(tex.r + tex.g + tex.b, 0.001);
	vec3 rn = skin_ref / max(skin_ref.r + skin_ref.g + skin_ref.b, 0.001);
	float skin_m = 1.0 - smoothstep(skin_tolerance, skin_tolerance * 1.8, distance(tn, rn) * 4.0);
	skin_m *= smoothstep(0.02, 0.06, lum);
	// Troca pelo brilho: o novo tom recebe a luz/sombra/detalhe da textura.
	float ref_lum = dot(skin_ref, vec3(0.299, 0.587, 0.114));
	vec3 new_skin = skin_color * clamp(lum / max(ref_lum, 0.01), 0.25, 1.9);
	vec3 col = mix(tex, new_skin, skin_m);

	// Cabelo / sobrancelhas: escuro e pouco saturado, só na cabeça.
	float head = smoothstep(0.4, 0.6, COLOR.a);
	float hair_m = head * (1.0 - smoothstep(hair_dark, hair_dark * 2.0, lum)) * (1.0 - smoothstep(0.35, 0.6, sat));
	col = mix(col, hair_color * (0.5 + 5.0 * lum), hair_m);

	float shirt_m = smoothstep(0.35, 0.65, COLOR.r) * has_shirt;
	float shorts_m = smoothstep(0.35, 0.65, COLOR.g) * recolor_shorts;
	float shoes_m = smoothstep(0.7, 0.85, COLOR.b) * has_shoes;
	float socks_m = smoothstep(0.3, 0.45, COLOR.b) * (1.0 - smoothstep(0.7, 0.85, COLOR.b)) * has_shoes;
	float cloth = max(max(shirt_m, shorts_m), max(shoes_m, socks_m));

	vec3 q = vec3(UV * 90.0, seed);
	float weave = 0.93 + 0.07 * noise3(q);
	float dirt_n = smoothstep(0.45, 0.85, fbm3(vec3(UV * 9.0, seed * 3.1)));
	vec3 dirt_col = vec3(0.33, 0.27, 0.2);
	col = mix(col, socks_color * weave, socks_m);
	col = mix(col, mix(shoes_color, dirt_col, dirt * 0.55) * weave, shoes_m);
	col = mix(col, shorts_color * weave * (0.75 + 0.5 * lum), shorts_m);
	col = mix(col, shirt_color * weave, shirt_m);
	col = mix(col, dirt_col, dirt * dirt_n * (cloth > 0.5 ? 0.55 : 0.2));

	ALBEDO = col;
	ROUGHNESS = mix(0.6, 0.92, cloth);
	SPECULAR = mix(0.35, 0.15, cloth);
}
