shader_type canvas_item;

// Hangar vivo: grid + haces + vineta (barato en Web).

uniform vec4 color_a : source_color = vec4(0.02, 0.05, 0.08, 1.0);
uniform vec4 color_b : source_color = vec4(0.05, 0.14, 0.18, 1.0);
uniform vec4 accent : source_color = vec4(0.15, 0.85, 0.75, 1.0);
uniform float speed = 0.35;

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV;
	float n = sin((uv.x + t) * 4.0) * cos((uv.y - t * 0.6) * 3.0) * 0.5 + 0.5;
	vec3 c = mix(color_a.rgb, color_b.rgb, n);

	// Grid hangar
	vec2 g = abs(fract(uv * vec2(14.0, 10.0) - vec2(t * 0.05, 0.0)) - 0.5);
	float grid = smoothstep(0.46, 0.5, max(g.x, g.y));
	c += accent.rgb * grid * 0.07;

	// Haz diagonal
	float beam = smoothstep(0.0, 0.08, abs(uv.x * 0.7 + uv.y * 0.4 - fract(t * 0.08 + 0.3)));
	beam = 1.0 - beam;
	c += accent.rgb * beam * 0.12;

	// Vineta
	float vig = smoothstep(0.95, 0.25, length(uv - 0.5));
	c *= mix(0.55, 1.0, vig);

	// Scanline suave
	float scan = 0.96 + 0.04 * sin(uv.y * 680.0 + t * 8.0);
	c *= scan;

	COLOR = vec4(c, 1.0);
}
