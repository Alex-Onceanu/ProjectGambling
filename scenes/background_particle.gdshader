shader_type canvas_item;

uniform sampler2D spades;
uniform sampler2D hearts;
uniform sampler2D diamonds;
uniform sampler2D clubs;
uniform vec4 color : source_color = vec4(vec3(0.0), 1.0);

void vertex() {

}

void fragment() {
	float span_ease = 1.;
	float span = pow(fract(2.2 * TIME), span_ease);

	float d = texture(clubs, UV).r;
	float wave_glow = 0.3;
	float wave = 4.0 * smoothstep(span - wave_glow / 2., span + wave_glow / 2., d) * smoothstep(span + wave_glow / 2., span - wave_glow / 2., d);
	float figure = 1.0 - smoothstep(0., wave_glow / 2., d);

	float disapear_ease = 2.0;
	float wave_col = 2.0 * wave * (pow(0.88, disapear_ease) - pow(min(span + 0.2, 0.9), disapear_ease));

	COLOR = vec4(vec3(color.rgb), min(1.0, figure + wave_col));
}
