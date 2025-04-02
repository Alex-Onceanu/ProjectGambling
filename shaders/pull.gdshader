shader_type canvas_item;

uniform vec3 clr : source_color = vec3(0.0);
uniform float modulate : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);
	uv *= 3.0;
	float intensity = 0.5 + 0.5 * sin(2.0 * TIME);
	uv *= modulate;
	COLOR = vec4(4.0 * clr, 1.2 * smoothstep(0.05, 0.28, modulate * modulate) * min(1.0, 0.5 * smoothstep(0.4, 0.95, 1.0 - dot(uv, uv)) + 0.5 * smoothstep(1.0 - intensity, 1.0, 1.0 - dot(uv, uv))));
}
