// Chão de BLOQUETES (bloquinhos de concreto intertravados), gasto e sujo:
// cada bloco com tom próprio, quinas gastas, juntas com terra e mato,
// blocos afundados/quebrados, alguns faltando (terra aparecendo), manchas e
// poças de água (rugosidade baixa = reflexo leve do céu e das cercas).
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec2 block_size = vec2(0.22, 0.11);
uniform float joint = 0.012;
uniform vec3 block_a : source_color = vec3(0.50, 0.48, 0.45);
uniform vec3 block_b : source_color = vec3(0.41, 0.39, 0.36);
uniform vec3 block_red : source_color = vec3(0.46, 0.35, 0.29);
uniform vec3 dirt_color : source_color = vec3(0.30, 0.23, 0.16);
uniform vec3 grass_color : source_color = vec3(0.20, 0.24, 0.11);
uniform float missing_amount = 0.02;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Fileiras desencontradas (meia peça), como na calçada de bloquete.
	float row = floor(p.y / block_size.y);
	vec2 q = vec2(p.x / block_size.x + mod(row, 2.0) * 0.5, p.y / block_size.y);
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float r = h2(cell);
	float r2 = h2(cell + 17.3);

	// Distância até a borda do bloco (em metros) -> juntas e quinas gastas.
	vec2 edge_m = min(f, 1.0 - f) * block_size;
	float e = min(edge_m.x, edge_m.y);
	float jw = joint * (0.7 + 0.8 * r2);
	float in_joint = 1.0 - smoothstep(jw * 0.6, jw, e);
	float bevel = smoothstep(jw, jw + 0.018, e);

	vec3 col = mix(block_a, block_b, r);
	col = mix(col, block_red, step(0.97, r2) * 0.6);
	col *= 0.9 + 0.14 * noise3(world_pos * 22.0);        // granulado do concreto
	col *= mix(0.82, 1.0, bevel);                        // quinas gastas mais escuras
	float grime = fbm3(world_pos * 0.6 + vec3(3.1, 0.0, 1.7));
	col = mix(col, dirt_color * 1.15, smoothstep(0.42, 0.78, grime) * 0.7); // sujeira/terra
	float worn = fbm3(world_pos * 0.12 + vec3(8.0, 0.0, 2.0));
	col *= mix(0.78, 1.05, worn);                                         // áreas mais escuras de uso
	float oil = smoothstep(0.72, 0.8, noise3(world_pos * 0.9 + vec3(1.0, 5.0, 2.0)));
	col = mix(col, vec3(0.12, 0.11, 0.10), oil * 0.5);                    // manchas de óleo

	// Juntas: terra e um pouco de mato.
	float grass = smoothstep(0.55, 0.75, noise3(world_pos * 1.3 + vec3(9.0)));
	vec3 joint_col = mix(dirt_color * 0.75, grass_color, grass * step(0.6, h2(cell + 3.7)) * 0.7);
	col = mix(col, joint_col, in_joint);

	// Bloco faltando ou quebrado: terra aparecendo.
	float missing = step(1.0 - missing_amount, h2(cell + 41.0));
	col = mix(col, dirt_color * (0.8 + 0.3 * noise3(world_pos * 9.0)), missing);
	float sunk = step(0.96, h2(cell + 7.7));
	col *= 1.0 - sunk * 0.18;

	// Poças rasas (água parada nos blocos afundados).
	float wet_n = fbm3(world_pos * 0.22 + vec3(21.0, 0.0, 4.0));
	float puddle = smoothstep(0.66, 0.72, wet_n) * puddle_amount;
	float damp = smoothstep(0.55, 0.66, wet_n) * puddle_amount;
	col *= 1.0 - damp * 0.35;

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.92, 0.75, bevel * 0.3), 0.08, max(puddle, missing * 0.0));
	SPECULAR = mix(0.25, 0.6, puddle);
	// Relevo: bisel dos blocos (normal inclinada perto da borda).
	vec2 grad = vec2(f.x < 0.5 ? -1.0 : 1.0, f.y < 0.5 ? -1.0 : 1.0);
	vec2 near = vec2(step(edge_m.x, edge_m.y), step(edge_m.y, edge_m.x));
	vec2 slope = grad * near * (1.0 - bevel) * 0.6 * (1.0 - puddle);
	NORMAL_MAP = normalize(vec3(slope.x * 0.5 + 0.5, slope.y * 0.5 + 0.5, 1.0));
}
