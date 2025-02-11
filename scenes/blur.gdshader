shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;
uniform sampler2D card_texture;
uniform float is_frontface;
uniform vec2 which_card;
uniform vec2 size;

void fragment(){
	float lod = abs(1.0 * sin(4.0 * TIME) + 2.5);
	vec2 uv = UV * 2.0 - vec2(1.0, 1.0);
	float n = 20.0;
	float border = pow(pow(uv.x, n) + pow(uv.y, n), 1.0 / n);
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, lod).xyz;
	
	vec2 front_uv = (uv + vec2(1.0, 1.0) + vec2(1.96, 2.0) * which_card) * size;
	
	vec4 card = texture(card_texture, front_uv);
	vec3 card_color = vec3(0.9, 0.7, 0.0);

	float border_alpha = 1.0 - smoothstep(0.94, 0.98, border);

	vec3 glow = vec3(1.0) - (vec3(1.0) - blurred) * (vec3(1.0) - card_color);

    COLOR = vec4(mix(glow, mix(card.xyz, card_color, (lod - 1.5) / 3.0), card.a), border_alpha * is_frontface);
}