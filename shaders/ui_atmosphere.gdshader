shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.04, 0.08, 0.12, 1.0);
uniform vec4 color_bot : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform vec4 accent : source_color = vec4(0.15, 0.85, 0.78, 1.0);
uniform vec4 danger : source_color = vec4(1.0, 0.28, 0.32, 1.0);
uniform float time_scale = 0.35;
uniform float scanline = 0.08;
uniform float vignette = 0.55;

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	vec3 col = mix(color_top.rgb, color_bot.rgb, uv.y);

	// Soft radial glow (hangar lamp)
	float d = distance(uv, vec2(0.5, 0.28));
	col += accent.rgb * 0.18 * exp(-d * 3.2);

	// Diagonal danger streak (beast side)
	float streak = smoothstep(0.02, 0.0, abs(uv.x + uv.y * 0.15 - 0.22 - sin(t) * 0.02));
	col += danger.rgb * streak * 0.12;

	// Moving grid
	vec2 g = uv * vec2(18.0, 12.0);
	float grid = max(step(0.96, fract(g.x + t * 0.2)), step(0.96, fract(g.y - t * 0.1)));
	col += accent.rgb * grid * 0.06;

	// Scanlines
	float scan = sin(uv.y * 780.0 + t * 8.0) * 0.5 + 0.5;
	col *= 1.0 - scan * scanline;

	// Vignette
	float vig = smoothstep(0.95, 0.25, length(uv - 0.5) * vignette * 1.4);
	col *= vig;

	COLOR = vec4(col, 1.0);
}
