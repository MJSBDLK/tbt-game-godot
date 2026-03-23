shader_type canvas_item;

global uniform float glow_alpha : hint_range(0.0, 1.0) = 0.85;
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform bool solid_rect = false;
uniform vec2 rect_size = vec2(80.0, 2.0);
// Enable a second glow pass at 2px distance for thicker outlines (e.g. larger text).
uniform bool double_glow = false;

void fragment() {
	vec4 current = texture(TEXTURE, UV);
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;

	if (solid_rect) {
		// Convert UV to pixel coords within the rect
		vec2 px = UV * rect_size;
		bool at_top = px.y < 1.0;
		bool at_bottom = px.y > rect_size.y - 1.0;
		bool at_left = px.x < 1.0;
		bool at_right = px.x > rect_size.x - 1.0;
		bool is_edge = at_top || at_bottom || at_left || at_right;
		bool is_corner = (at_left || at_right) && (at_top || at_bottom);

		if (is_edge && !is_corner) {
			COLOR = vec4(glow_color.rgb, glow_alpha);
		} else if (is_edge && is_corner) {
			COLOR = vec4(0.0);
		} else {
			COLOR = current * COLOR;
		}
	} else {
		// TextureRect mode: glow around transparent edges of texture
		float up = texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a;
		float down = texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a;
		float left = texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a;
		float right = texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a;

		float neighbor = max(max(up, down), max(left, right));

		if (double_glow) {
			// Second pass: sample 2px out in orthogonal + diagonal directions.
			float up2 = texture(TEXTURE, UV + vec2(0.0, -pixel_size.y * 2.0)).a;
			float down2 = texture(TEXTURE, UV + vec2(0.0, pixel_size.y * 2.0)).a;
			float left2 = texture(TEXTURE, UV + vec2(-pixel_size.x * 2.0, 0.0)).a;
			float right2 = texture(TEXTURE, UV + vec2(pixel_size.x * 2.0, 0.0)).a;
			float ul = texture(TEXTURE, UV + vec2(-pixel_size.x, -pixel_size.y)).a;
			float ur = texture(TEXTURE, UV + vec2(pixel_size.x, -pixel_size.y)).a;
			float dl = texture(TEXTURE, UV + vec2(-pixel_size.x, pixel_size.y)).a;
			float dr = texture(TEXTURE, UV + vec2(pixel_size.x, pixel_size.y)).a;
			float outer = max(max(max(up2, down2), max(left2, right2)),
			                  max(max(ul, ur), max(dl, dr)));
			// Outer ring is dimmer than inner ring.
			neighbor = max(neighbor, outer * 0.6);
		}

		float glow = neighbor * (1.0 - current.a);

		vec4 tinted = current * COLOR;
		COLOR = mix(vec4(glow_color.rgb, glow * glow_alpha), tinted, tinted.a);
	}
}
