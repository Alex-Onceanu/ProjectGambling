shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV, 2.0);
	COLOR = color;
}
