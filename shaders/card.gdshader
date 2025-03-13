shader_type canvas_item;

uniform sampler2D front_tex;
uniform sampler2D back_tex;
uniform float is_frontface;
uniform vec2 which_card;
uniform vec2 size;

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);

	vec2 front_uv = (uv + vec2(1.0, 1.0) + vec2(1.96, 2.0) * which_card) * size;

	vec4 front = texture(front_tex, front_uv);
	vec4 back = texture(back_tex, UV);

	float n = 40.0;
	float border = pow(pow(abs(uv.x), n) + pow(abs(uv.y), n), 1.0 / n);

	COLOR = vec4(0.6 * mix(back, front, is_frontface).xyz, 1.0 - smoothstep(0.96, 0.98, border));
}
