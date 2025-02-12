shader_type canvas_item;

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);
	
	float n = 24.0;
	float norm_n = pow(pow(uv.x, n) + pow(uv.y, n), 1.0 / n);

	float border_alpha = smoothstep(0.85, 0.87, norm_n) * (1.0 - smoothstep(0.98, 1.0, norm_n));
	vec4 border = vec4(vec3(0.69, 0.517, 0.227), border_alpha);

	float dark_alpha = (1.0 - step(0.86, norm_n));
	vec4 dark_table = vec4(0.776, 0.207, 0.168, dark_alpha);

	float theta = TIME;
	//mat3 rotate = mat3(vec3(cos(theta), sin(theta), 1.0), vec3(-sin(theta), cos(theta), 1.0), vec3(1.0, 1.0, 1.0));

	vec3 light = normalize(vec3(0.1, 0.2, -1.0)) * 0.05;

	//COLOR = vec4(clamp(dot(velvet, vec3(0.0, 0.0, -1.0)), 0.0, 1.0));
	COLOR = border * border.a + dark_table * dark_table.a;
}



//void fragment() {
	//vec2 uv = UV * 2.0 - vec2(1.0, 1.0);
	//
	//float n = 24.0;
	//float norm_n = pow(pow(uv.x, n) + pow(uv.y, n), 1.0 / n);
	//
	//float border_alpha = smoothstep(0.8, 0.86, norm_n) * (1.0 - smoothstep(0.98, 1.0, norm_n));
	//vec4 border = vec4(vec3(0.345, 0.24, 0.15), border_alpha);
	//
	//
	//COLOR = border + smoothstep(0.95, 0.93, norm_n) * vec4(0.443, 0.074, 0.05, 1.0);
//}

