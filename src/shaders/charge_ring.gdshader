shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Anel de força sob o jogador: enche no sentido horário a partir da frente.
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float inner = 0.64;
uniform float outer = 0.84;

void fragment() {
	vec2 p = UV * 2.0 - 1.0; // -1..1
	float r = length(p);
	float aa = fwidth(r) * 1.5;
	float band = smoothstep(inner - aa, inner, r) * (1.0 - smoothstep(outer, outer + aa, r));
	if (band <= 0.001) discard;
	// ângulo: 0 na frente do jogador (-Z local = V para cima), sentido horário
	float ang = atan(p.x, -p.y);
	float t = fract(ang / 6.28318 + 1.0);
	float on = step(t, fill);
	vec3 col = mix(vec3(0.25, 0.95, 0.3), vec3(1.0, 0.2, 0.15), fill);
	vec3 base = vec3(0.05);
	ALBEDO = mix(base, col, on);
	ALPHA = band * mix(0.35, 0.95, on);
}
