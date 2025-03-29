shader_type canvas_item;

uniform sampler2D noise;
uniform sampler2D wood;


void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);

	float border_alpha = step(0.85, dot(uv, uv)) * (1.0 - smoothstep(0.98, 1.0, dot(uv, uv)));
	vec4 border = vec4(vec3(0.345, 0.2, 0.15), border_alpha);

	float dark_alpha = (1.0 - step(0.85, dot(uv, uv)));
	vec4 dark_table = vec4((0.5 + 0.5 * (1.0 - dot(uv, uv))) * vec3(0.15, 0.5, 0.2), dark_alpha);

	vec3 velvet = normalize(texture(noise, 0.87 * UV).rgb) * dark_alpha;
	vec3 wood_nm = normalize(texture(wood, 0.87 * UV).rgb) * border_alpha;

	float theta = TIME;
	//mat3 rotate = mat3(vec3(cos(theta), sin(theta), 1.0), vec3(-sin(theta), cos(theta), 1.0), vec3(1.0, 1.0, 1.0));

	vec3 light = normalize(vec3(0.1, 0.2, -1.0)) * 0.05;

	//COLOR = vec4(clamp(dot(velvet, vec3(0.0, 0.0, -1.0)), 0.0, 1.0));
	vec4 bright_color = dot(wood_nm, 3.0 * light) + border * border.a + dark_table * dark_table.a + dot(velvet, light);
	COLOR = vec4(0.4 * bright_color.xyz, border_alpha + dark_alpha);
}
