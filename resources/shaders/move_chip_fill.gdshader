shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.8, 0.3, 0.1, 1.0);
uniform vec4 empty_color : source_color = vec4(0.3, 0.1, 0.05, 1.0);
uniform vec4 border_color : source_color = vec4(0.15, 0.15, 0.15, 1.0);
uniform float fill_percent : hint_range(0.0, 1.0) = 0.6;
uniform float skew_angle : hint_range(0.0, 45.0) = 45.0;
uniform float border_px : hint_range(0.0, 4.0) = 1.0;
uniform float radius_px : hint_range(0.0, 10.0) = 3.0;
uniform vec2 rect_size = vec2(100.0, 14.0);
// VOID lock: 0 = normal, 1 = fully grayscale. Pulls the chip's fill/border toward
// luminance grey so a void-locked move/passive reads as "dead." Pairs with the
// void_lock_overlay (shadow + sparkles) drawn on top. See VoidLockOverlay.
uniform float lock_desaturate : hint_range(0.0, 1.0) = 0.0;

// Scheme-glyph drop shadow (Lawrence 2026-07-20): never a black overlay —
// the shadow is the occluded surface pushed one step DOWN its own ramp, so
// it splits across the usage boundary per pixel. Rendering it HERE reuses
// this shader's own fill/empty test: the split can't drift from the real
// boundary. Mask = the glyph's shape texture; rect in chip pixels.
uniform bool scheme_shadow_enabled = false;
uniform sampler2D scheme_shadow_mask : filter_nearest;
uniform vec4 scheme_shadow_rect = vec4(0.0, 0.0, 12.0, 12.0);
uniform vec4 fill_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 empty_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Scheme-glyph ink (RQD 2026-07-26, "borderline invisible over Robo"): the
// glyph body renders here too, same mask, un-offset rect — so each side of
// the usage boundary gets the ink cut that contrasts with ITS body (light
// bone over dark empties, dark bone over light fills like Gray 8). Most
// elements pick light/light and look exactly as before. Drawn after the
// shadow: ink covers shadow where they overlap.
uniform bool scheme_ink_enabled = false;
uniform vec4 scheme_ink_rect = vec4(0.0, 0.0, 12.0, 12.0);
uniform vec4 fill_ink_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 empty_ink_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float rounded_box_sdf(vec2 center_dist, vec2 half_size, float radius) {
	vec2 q = abs(center_dist) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 pos_px = UV * rect_size;
	vec2 center = rect_size * 0.5;

	float dist = rounded_box_sdf(pos_px - center, center, radius_px);

	// Inner color: fill or empty based on diagonal threshold
	float skew = tan(radians(skew_angle)) * rect_size.y / (2.0 * rect_size.x);
	float threshold = fill_percent + skew - (skew * 2.0 * UV.y);
	vec4 inner = UV.x < threshold ? fill_color : empty_color;

	if (scheme_shadow_enabled) {
		vec2 mask_uv = (pos_px - scheme_shadow_rect.xy) / scheme_shadow_rect.zw;
		if (mask_uv.x >= 0.0 && mask_uv.x < 1.0 && mask_uv.y >= 0.0 && mask_uv.y < 1.0) {
			float mask_alpha = texture(scheme_shadow_mask, mask_uv).a;
			vec4 shadow = UV.x < threshold ? fill_shadow_color : empty_shadow_color;
			inner = mix(inner, shadow, mask_alpha);
		}
	}

	if (scheme_ink_enabled) {
		vec2 ink_uv = (pos_px - scheme_ink_rect.xy) / scheme_ink_rect.zw;
		if (ink_uv.x >= 0.0 && ink_uv.x < 1.0 && ink_uv.y >= 0.0 && ink_uv.y < 1.0) {
			float ink_alpha = texture(scheme_shadow_mask, ink_uv).a;
			vec4 ink = UV.x < threshold ? fill_ink_color : empty_ink_color;
			inner = mix(inner, ink, ink_alpha);
		}
	}

	// Blend border -> inner using SDF distance
	float border_blend = smoothstep(0.0, -border_px, dist);
	vec4 shape_color = mix(border_color, inner, border_blend);

	// VOID lock: collapse toward perceived luminance (Rec. 601 weights).
	if (lock_desaturate > 0.0) {
		float luma = dot(shape_color.rgb, vec3(0.299, 0.587, 0.114));
		shape_color.rgb = mix(shape_color.rgb, vec3(luma), lock_desaturate);
	}

	// Anti-aliased outer edge
	float alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
	COLOR = vec4(shape_color.rgb, shape_color.a * alpha);
}
