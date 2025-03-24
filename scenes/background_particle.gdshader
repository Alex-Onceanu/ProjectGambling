shader_type canvas_item;

uniform sampler2D spades;
uniform sampler2D hearts;
uniform sampler2D diamonds;
uniform sampler2D clubs;
uniform vec4 color : source_color = vec4(vec3(0.0), 1.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);

	float d = texture(diamonds, UV).r;
	float amp = 0.389;
	//float span = amp + 0.01 + amp * sin(3.0 * TIME);
	float span_ease = 0.6;
	float span = 0.8 * pow(fract(1.2 * TIME), span_ease);
	float wave_glow = 0.3;
	float wave = 4.0 * smoothstep(span - wave_glow / 2., span + wave_glow / 2., d) * smoothstep(span + wave_glow / 2., span - wave_glow / 2., d);
	float figure = 1.0 - smoothstep(0., wave_glow / 2., d);

	COLOR = color * (wave + figure);
}
