// Bola de futebol (icosaedro truncado): 12 pentágonos pretos + 20 hexágonos
// brancos, com costuras, gomos levemente estufados e desgaste de bola de rua.
// Os gomos usam a direção local (giram com a bola: rolagem visível).
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 white_panel : source_color = vec3(0.93, 0.92, 0.88);
uniform vec3 black_panel : source_color = vec3(0.07, 0.07, 0.08);
uniform float scuff : hint_range(0.0, 1.0) = 0.4;

varying vec3 local_pos;

const float PHI = 1.618034;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(local_pos);
	// Centros dos pentágonos: vértices do icosaedro.
	vec3 pent[12] = vec3[](
		vec3(0.0, 1.0, PHI), vec3(0.0, -1.0, PHI), vec3(0.0, 1.0, -PHI), vec3(0.0, -1.0, -PHI),
		vec3(1.0, PHI, 0.0), vec3(-1.0, PHI, 0.0), vec3(1.0, -PHI, 0.0), vec3(-1.0, -PHI, 0.0),
		vec3(PHI, 0.0, 1.0), vec3(-PHI, 0.0, 1.0), vec3(PHI, 0.0, -1.0), vec3(-PHI, 0.0, -1.0));
	// Centros dos hexágonos: vértices do dodecaedro.
	float ip = 1.0 / PHI;
	vec3 hexa[20] = vec3[](
		vec3(1.0, 1.0, 1.0), vec3(1.0, 1.0, -1.0), vec3(1.0, -1.0, 1.0), vec3(1.0, -1.0, -1.0),
		vec3(-1.0, 1.0, 1.0), vec3(-1.0, 1.0, -1.0), vec3(-1.0, -1.0, 1.0), vec3(-1.0, -1.0, -1.0),
		vec3(0.0, ip, PHI), vec3(0.0, -ip, PHI), vec3(0.0, ip, -PHI), vec3(0.0, -ip, -PHI),
		vec3(ip, PHI, 0.0), vec3(-ip, PHI, 0.0), vec3(ip, -PHI, 0.0), vec3(-ip, -PHI, 0.0),
		vec3(PHI, 0.0, ip), vec3(PHI, 0.0, -ip), vec3(-PHI, 0.0, ip), vec3(-PHI, 0.0, -ip));
	float best = -2.0;
	float second = -2.0;
	bool is_pent = false;
	for (int i = 0; i < 12; i++) {
		float d = dot(n, normalize(pent[i]));
		if (d > best) { second = best; best = d; is_pent = true; }
		else if (d > second) { second = d; }
	}
	for (int i = 0; i < 20; i++) {
		float d = dot(n, normalize(hexa[i]));
		if (d > best) { second = best; best = d; is_pent = false; }
		else if (d > second) { second = d; }
	}
	vec3 col = is_pent ? black_panel : white_panel;
	// Costura entre gomos (onde dois centros ficam quase à mesma distância).
	float seam = smoothstep(0.004, 0.018, best - second);
	col *= mix(0.35, 1.0, seam);
	// Desgaste: sujeira e arranhões de bola de rua.
	float dirt = noise3(local_pos * 55.0) * noise3(local_pos * 14.0 + vec3(3.0));
	col = mix(col, vec3(0.36, 0.31, 0.25), smoothstep(0.25, 0.6, dirt) * scuff);
	ALBEDO = col;
	ROUGHNESS = mix(0.5, 0.8, 1.0 - seam);
	SPECULAR = 0.45;
	// Gomos levemente estufados: normal inclinada perto da costura.
	NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.0;
}
