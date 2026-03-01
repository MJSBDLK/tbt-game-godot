shader_type canvas_item;

global uniform float glow_alpha : hint_range(0.0, 1.0) = 0.85;
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);

void fragment() {
	vec4 current = texture(TEXTURE, UV);
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;

	float up = texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a;
	float down = texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a;
	float left = texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a;
	float right = texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a;

	float neighbor = max(max(up, down), max(left, right));
	float glow = neighbor * (1.0 - current.a);

	vec4 tinted = current * COLOR;
	COLOR = mix(vec4(glow_color.rgb, glow * glow_alpha), tinted, tinted.a);
}
