shader_type canvas_item;

uniform sampler2D spades;
uniform sampler2D hearts;
uniform sampler2D diamonds;
uniform sampler2D clubs;
uniform float frequency;
uniform float phase;
uniform float which_figure;
uniform float fade;

void fragment() {
	float zoom = 1.0 + 0.4 * (1.0 - pow(2.0 * fract(frequency * TIME + phase) - 1.0, 6.0));

	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);
	uv *= zoom;

	uv = mix(vec2(0.01, 0.01), (uv + vec2(1.0, 1.0)) / 2.0, step(dot(uv, uv), 0.8));

	float span_ease = 0.25;
	float span = pow(fract(frequency * TIME / 2.0 + phase / 2.0), span_ease);

	float d_clubs = texture(clubs, uv).r;
	float d_hearts = texture(hearts, uv).r;
	float d_spades = texture(spades, uv).r;
	float d_diamonds = texture(diamonds, uv).r;
	float ld[] = { d_clubs,d_hearts,d_spades,d_diamonds };

	float D_clubs = texture(clubs, UV).r;
	float D_hearts = texture(hearts, UV).r;
	float D_spades = texture(spades, UV).r;
	float D_diamonds = texture(diamonds, UV).r;
	float lD[] = { D_clubs,D_hearts,D_spades,D_diamonds };

	vec3 col_clubs = 0.125 * vec3(0.196, 0.349, 0.322);
	vec3 col_hearts = vec3(0.9, 0.04, 0.04);
	vec3 col_spades = 0.3 * vec3(0.0392, 0.0588, 0.09216);
	vec3 col_diamonds = vec3(1.0, 0.15, 0.0);
	vec3 lcol[] = { col_clubs,col_hearts,col_spades,col_diamonds };

	float D1 = lD[int(which_figure) % 4];
	float d1 = ld[int(which_figure) % 4];
	vec3 color1 = lcol[int(which_figure) % 4];

	float D2 = lD[(int(which_figure) + 1) % 4];
	float d2 = ld[(int(which_figure) + 1) % 4];
	vec3 color2 = lcol[(int(which_figure) + 1) % 4];

	float D = mix(D1, D2, fract(which_figure));
	float d = mix(d1, d2, fract(which_figure));
	vec3 color = mix(color1, color2, fract(which_figure));

	float wave_glow = 0.4;
	float wave = min(1.0, 6.0 * smoothstep(span - wave_glow, span, D) * smoothstep(span, span - wave_glow, D));
	float figure = 1.0 - smoothstep(0., 0.15, d);

	float disapear_ease = 1.0;
	float wave_col = 2.0 * wave * (1.0 - pow(min(span, 1.0), disapear_ease));

	float alpha = min(1.0, figure + wave_col);

	COLOR = vec4(vec3(color.rgb) * alpha, fade * 0.7 * alpha);
}
