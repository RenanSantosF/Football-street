// Casca de árvore (tronco e galhos): sulcos verticais, musgo e liquens.
shader_type spatial;

#include "res://src/shaders/noise.gdshaderinc"

uniform vec3 bark_light : source_color = vec3(0.36, 0.30, 0.24);
uniform vec3 bark_dark : source_color = vec3(0.16, 0.13, 0.10);
uniform vec3 moss : source_color = vec3(0.28, 0.33, 0.16);

varying vec3 local_pos;
varying vec3 world_pos;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ang = atan(local_pos.x, local_pos.z);
	float ridges = noise3(vec3(ang * 3.5, local_pos.y * 1.4, 0.0) * 2.0);
	float fine = noise3(world_pos * 25.0);
	vec3 col = mix(bark_dark, bark_light, smoothstep(0.3, 0.75, ridges * 0.7 + fine * 0.3));
	float m = smoothstep(0.6, 0.8, noise3(world_pos * 2.0 + vec3(4.0)));
	col = mix(col, moss, m * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.97;
	NORMAL_MAP = vec3(0.5 + (ridges - 0.5) * 0.6, 0.5, 1.0);
}
