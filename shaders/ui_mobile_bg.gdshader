shader_type canvas_item;

## Atmosfera ligera animada (barata en móvil/Web).

uniform vec4 color_a : source_color = vec4(0.03, 0.07, 0.1, 1.0);
uniform vec4 color_b : source_color = vec4(0.06, 0.12, 0.16, 1.0);
uniform float speed = 0.25;

void fragment() {
	float t = TIME * speed;
	float n = sin((UV.x + t) * 3.2) * cos((UV.y - t * 0.7) * 2.4) * 0.5 + 0.5;
	vec3 c = mix(color_a.rgb, color_b.rgb, n);
	float beam = smoothstep(0.48, 0.52, fract(UV.x * 2.0 + t * 0.15 + UV.y * 0.2));
	c += vec3(0.05, 0.18, 0.2) * beam * 0.35;
	COLOR = vec4(c, 1.0);
}
