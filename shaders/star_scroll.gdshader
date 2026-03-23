shader_type canvas_item;

// Horizontal scroll offset, driven from GDScript (not TIME-based)
// so the script can ease the speed dynamically.
uniform float scroll_offset : hint_range(-10000.0, 10000.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + scroll_offset);
	COLOR = texture(TEXTURE, uv) * COLOR;
}
