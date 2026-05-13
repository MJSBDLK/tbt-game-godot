// "Projection" effect for HD line-art portraits — gives the line art a
// holographic / glass-projection look. Designed to be assigned to the
// `material` of the TextureRect mirror inside HDPortraitSlot.
//
// Three layers, all tunable per-instance:
//   1. Tint pass — collapses the source colors to a luminance value, then
//      multiplies by `tint_color`. The result is a monochrome portrait in
//      the chosen color, preserving the original shading. `tint_strength`
//      blends between the original full-color portrait (0.0) and the
//      monochrome projection (1.0).
//   2. Outer glow — samples alpha in a small ring around each pixel; where
//      the current pixel is transparent but neighbors are opaque, draws
//      `glow_color`. This is the "light bleed" around the silhouette.
//   3. Scanlines — subtle horizontal sine-wave darkening, gated to non-
//      transparent regions so the effect doesn't spill into the panel
//      background. Optional time-based scroll via `scanline_speed`.
shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.859, 0.953, 1.0, 1.0);    // Azure 9
uniform vec4 glow_color : source_color = vec4(0.298, 0.549, 0.733, 1.0);  // Azure 5
uniform float tint_strength : hint_range(0.0, 1.0) = 1.0;

// Glow radius is in source-texture pixels — at the HD source's native
// resolution. A radius of 2 on a 1024-pixel-wide atlas is much subtler
// than the same radius on a 64-pixel sprite, so tune per-asset.
uniform float glow_radius : hint_range(0.0, 16.0) = 2.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_density : hint_range(10.0, 300.0) = 80.0;
uniform float scanline_speed : hint_range(-5.0, 5.0) = 0.0;


void fragment() {
	vec4 src = texture(TEXTURE, UV);

	// 1. Tint — luminance × tint_color, mixed against the original by tint_strength.
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = tint_color.rgb * lum;
	vec3 final_rgb = mix(src.rgb, tinted, tint_strength);
	float final_alpha = src.a;

	// 2. Outer glow — 8-point ring around the current pixel; if any neighbor
	// is opaque while we ourselves are transparent, paint the glow color.
	float halo = 0.0;
	if (glow_radius > 0.0) {
		vec2 step_size = TEXTURE_PIXEL_SIZE * glow_radius;
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.7853982;  // 45° increments
			vec2 offset = vec2(cos(angle), sin(angle)) * step_size;
			halo = max(halo, texture(TEXTURE, UV + offset).a);
		}
		halo *= (1.0 - src.a) * glow_strength;
	}
	final_rgb = mix(final_rgb, glow_color.rgb, halo);
	final_alpha = max(final_alpha, halo * glow_color.a);

	// 3. Scanlines — only where final alpha is meaningful, so the lines
	// don't darken transparent panel background.
	if (scanline_strength > 0.0 && final_alpha > 0.01) {
		float scan = sin((UV.y * scanline_density) + TIME * scanline_speed);
		float scan_factor = mix(1.0, 0.5 + scan * 0.5, scanline_strength);
		final_rgb *= scan_factor;
	}

	COLOR = vec4(final_rgb, final_alpha);
}
