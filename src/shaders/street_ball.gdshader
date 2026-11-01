// Bola de rua gasta. Os gomos usam coordenadas locais do objeto, então
// giram junto com a bola e deixam a rolagem visível.
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.92, 0.90, 0.84);
uniform vec3 color_b : source_color = vec3(0.12, 0.22, 0.45);
uniform float scuff : hint_range(0.0, 1.0) = 0.35;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(local_pos);
	float s = sign(n.x) * sign(n.y) * sign(n.z);
	float seam = min(min(abs(n.x), abs(n.y)), abs(n.z));
	vec3 col = s > 0.0 ? color_a : color_b;
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.06, seam));
	float dirt = noise3(local_pos * 60.0) * noise3(local_pos * 17.0);
	col = mix(col, vec3(0.30, 0.27, 0.23), dirt * scuff);
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
