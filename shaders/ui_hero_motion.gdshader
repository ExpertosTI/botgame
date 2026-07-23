shader_type canvas_item;

// Ken Burns + scanlines + tint pulse (estilo “GIF” ligero para Web).

uniform float time_scale = 1.0;
uniform float zoom_amp = 0.06;
uniform float scan_strength = 0.08;
uniform vec4 tint_a : source_color = vec4(0.15, 0.75, 0.85, 1.0);
uniform vec4 tint_b : source_color = vec4(0.9, 0.2, 0.25, 1.0);

void fragment() {
	float t = TIME * time_scale;
	float zoom = 1.0 + zoom_amp * sin(t * 0.35);
	vec2 uv = (UV - 0.5) / zoom + 0.5;
	uv += vec2(sin(t * 0.22) * 0.012, cos(t * 0.18) * 0.01);
	uv = clamp(uv, vec2(0.001), vec2(0.999));

	vec4 col = texture(TEXTURE, uv);
	float scan = sin((UV.y + t * 0.15) * 180.0) * 0.5 + 0.5;
	col.rgb *= 1.0 - scan_strength * scan;

	float mix_t = 0.5 + 0.5 * sin(t * 0.55);
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, mix_t);
	col.rgb = mix(col.rgb, col.rgb * tint, 0.18);

	float vig = smoothstep(0.95, 0.35, length(UV - 0.5));
	col.rgb *= mix(0.72, 1.0, vig);

	COLOR = col;
}
