shader_type canvas_item;

uniform sampler2D front_tex;
uniform sampler2D back_tex;
uniform float is_frontface;
uniform vec2 which_card;
uniform vec2 size;
uniform float which_texture_type : hint_range(0.0, 1.0) = 1.0;
uniform float which_background : hint_range(0.0, 1.0) = 1.0;

uniform float strength: hint_range(0., 1.) = 0.5;
uniform float speed: hint_range(0., 10.) = 0.5;
uniform float angle: hint_range(0., 360.) = 0.;

vec4 rainbow(vec2 uv) {
	float hue = uv.x * cos(radians(angle)) - uv.y * sin(radians(angle));
	hue = fract(hue + fract(TIME  * speed));
	float x = 1. - abs(mod(hue / (1./ 6.), 2.) - 1.);
	vec3 rainbow;
	if(hue < 1./6.){
		rainbow = vec3(1., x, 0.);
	} else if (hue < 1./3.) {
		rainbow = vec3(x, 1., 0);
	} else if (hue < 0.5) {
		rainbow = vec3(0, 1., x);
	} else if (hue < 2./3.) {
		rainbow = vec3(0., x, 1.);
	} else if (hue < 5./6.) {
		rainbow = vec3(x, 0., 1.);
	} else {
		rainbow = vec3(1., 0., x);
	}
	vec4 color = vec4(1.0);
	return mix(color, vec4(rainbow, color.a), strength);
}

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);

	vec2 type_1 = (UV + which_card) * size;
	vec2 type_2 = (UV - vec2(13.0, 16.0) / (1.0 * vec2(1846., 760.)) * (which_card - vec2(4.5, 1.0)) + which_card) * size;
	vec2 front_uv = mix(type_1, type_2, which_texture_type);

	vec4 front = texture(front_tex, front_uv);
	front = front * front;
	vec4 back = texture(back_tex, UV);
	back = back * back;

	float n = 40.0;
	float border = pow(pow(abs(uv.x), n) + pow(abs(uv.y), n), 1.0 / n);

	float card_alpha = 1.0 - smoothstep(0.96, 0.98, border);
	
	vec3 rainbow_background = rainbow(UV).xyz * rainbow(UV).xyz * rainbow(UV).xyz;
	vec3 background = mix(vec3(1.0), rainbow_background, which_background);
	
	vec3 front_clr = mix(background, front.rgb * card_alpha, front.a);
	
	float alpha = mix(card_alpha * back.a, card_alpha, is_frontface);
	COLOR = vec4(mix(back.rgb, front_clr, is_frontface), alpha);
}
