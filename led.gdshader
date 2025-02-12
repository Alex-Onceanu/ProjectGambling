shader_type canvas_item;


vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.283185*(c*t+d) );
}

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);
	
	float border_alpha = (1.0 - dot(uv, uv));
	
	float t = abs(sin(0.4 * TIME));
	vec3 gradient = vec3(1.0, 0.0, 0.0) * t + (1.0 - t) * vec3(1.0, 1.0, 0.0);
	
	COLOR = vec4(gradient * border_alpha, step(0.1, border_alpha));
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
