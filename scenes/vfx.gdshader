shader_type canvas_item;


vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.283185*(c*t+d) );
}

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);
	
	float n = 18.0;
	float norm_n = pow(pow(uv.x, n) + pow(uv.y, n), 1.0 / n);
	
	// 0.48 * (...) + pi := nombre magique quand on fait pas "t *= 0.3"
	float t = 0.53 * (atan(uv.y, uv.x) + TIME) + 3.14;
	t *= 0.3;

	vec3 gradient = palette(t,vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25));
	
	COLOR = 1.5 * smoothstep(0.99, 0.75, norm_n) * smoothstep(0.65, 0.85, norm_n) * vec4(gradient, 1.0);
}
