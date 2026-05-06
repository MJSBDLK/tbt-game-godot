shader_type canvas_item;

uniform sampler2D noise_tex : filter_nearest, repeat_disable;
uniform vec2 icon_size = vec2(10.0, 10.0);
uniform float tick_interval = 0.12;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 noise_size = vec2(textureSize(noise_tex, 0));
	float tick = floor(TIME / tick_interval);
	vec2 max_offset = max(noise_size - icon_size, vec2(0.0));
	vec2 offset = floor(vec2(hash(tick), hash(tick + 17.0)) * (max_offset + 1.0));
	vec2 pixel_uv = (UV * icon_size + offset) / noise_size;
	COLOR = texture(noise_tex, pixel_uv);
}
