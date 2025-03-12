shader_type canvas_item;

vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.283185*(c*t+d) );
}

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);

	float n = 46.0;
	float norm_n = 1.1 * pow(pow(abs(uv.x) * 1.024, n) + pow(abs(uv.y) * 0.95, n), 1.0 / n);

	float border_alpha = step(0.7, norm_n) * (1.0 - smoothstep(0.99, 1.02, norm_n));
	vec4 border = (0.8 + 0.2 * uv.y + 0.2 * abs(sin(9.0 * uv.y + 9.0 * uv.x))) * vec4(0.49, 0.46, 0.202, border_alpha);

	float rect_alpha = smoothstep(-0.81, -0.79, uv.x) * smoothstep(-0.72, -0.7, uv.y) * smoothstep(-0.82, -0.8, -uv.x) * smoothstep(-0.72, -0.7, -uv.y);
	vec4 interior = vec4(0.4 + 0.3 * (1.0 - dot(uv, uv)), 0.0, 0.0, rect_alpha);

	vec4 background = border * (1.0 - rect_alpha) + interior;

	// 0.48 * (...) + pi := nombre magique quand on fait pas "t *= 0.3"
	float t = 0.53 * (atan(uv.y, uv.x) - 3.0 * TIME) + 3.14;
	t *= 0.3;

/*
[[1.300 1.100 0.500] [0.500 0.500 0.500] [0.500 0.500 0.500] [0.500 0.500 0.500]]
*/

	//vec3 gradient = palette(t,vec3(1.00, 0.61, 0.76),vec3(0.00, 0.29, 1.00),vec3(1.00, 0.00, 1.00),vec3(0.76, 0.00, 0.51));
	//vec3 gradient = mix(vec3(1.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), sin(3.0 * t));
	//vec3 gradient = palette(t, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67));
	vec3 gradient = palette(8.0 * t, 0.6 * vec3(1.300, 1.100, 0.500), vec3(0.500, 0.500, 0.500), vec3(0.500, 0.500, 0.500), vec3(0.500, 0.500, 0.500));
	gradient = floor(8.0 * gradient) / 8.0;

	//vec3 led_color = vec3(0.7, 0.7, 0.9);
	vec3 led_color = 4.0 * gradient;
	float led_n = 0.8;
	float led_size = 0.06;
	vec2 offset = vec2(0.085, 0.0);
	vec2 led_deformation = vec2(0.8, 0.3);

	vec2 led_uv = led_size * (fract((uv + offset) * led_deformation * 14.0) - 0.5);

	float one_led_alpha = 0.2 * (1.0 - pow(1000.0 * dot(led_uv, led_uv), led_n));
	vec4 leds = vec4(led_color.r + (0.5 + led_color.r - led_color.g) * (1.0 - pow(1000.0 * dot(led_uv, led_uv), 2.0 * led_n)), led_color.g + 0.5 * (1.0 - pow(1000.0 * dot(led_uv, led_uv), 2.0 * led_n)), led_color.b, one_led_alpha * border_alpha * (1.0 - rect_alpha));

	COLOR = vec4(0.77 * mix(background.xyz, leds.xyz, smoothstep(0.0, 0.2, leds.a)), background.a);
	//COLOR = background;
	//COLOR = background + vec4(leds.xyz * step(0.1, leds.a), background.a);
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
