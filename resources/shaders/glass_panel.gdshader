// Glass-surface effect for HUD panels — applied via a CanvasItem `material`
// on a Panel / PanelContainer / ColorRect that has a StyleBoxFlat or fill.
// The shader processes every pixel the host draws (StyleBoxFlat bg + border)
// and layers four passes on top:
//   1. Azure tint — mixes the host's base color toward `glass_tint`.
//   2. Top-down gradient — brighter near the top of the rect, simulating an
//      overhead light source on the glass surface.
//   3. Top-edge highlight — a sharper bright band along the upper edge to
//      sell "polished glass" rather than "flat panel."
//   4. Horizontal scanlines — subtle, gated by `scanline_strength` so they
//      can be killed entirely if they read as noisy.
//
// All parameters are exported as uniforms so the host can be tuned in the
// inspector without touching shader code. Defaults aim for "subtle blue
// glass with a soft top highlight" — increase strengths for more flair.
shader_type canvas_item;

uniform vec4 glass_tint : source_color = vec4(0.298, 0.549, 0.733, 0.4);     // Azure 5 @ 40% mix
uniform vec4 highlight_color : source_color = vec4(0.859, 0.953, 1.0, 1.0);  // Azure 9
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.3;
uniform float top_highlight_strength : hint_range(0.0, 1.0) = 0.25;
uniform float top_highlight_falloff : hint_range(1.0, 16.0) = 4.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.1;
uniform float scanline_density : hint_range(10.0, 300.0) = 60.0;
// Scanline scroll velocity in UV-space units per second. Positive = downward
// marquee, negative = upward. 0.05 = a full panel traversal every 20 seconds
// (slow ambient drift); 0.5 = once every 2 seconds (assertive). 0 = static.
uniform float scanline_speed : hint_range(-2.0, 2.0) = 0.0;

// === Every-Nth-scanline accent ===
// On every Nth scanline cycle, brightens the row by `accent_strength`.
// Setting accent_strength = 0 disables the effect entirely.
uniform float accent_every : hint_range(2.0, 64.0) = 32.0;
uniform float accent_strength : hint_range(0.0, 2.0) = 0.0;

// === Reference-resolution effects ===
// Chunk size in REFERENCE pixels (640×360 space). 1.0 = one chunk per
// reference pixel = scale_factor actual screen pixels each. Larger values
// give chunkier static. Independent of UV/atlas — we quantize FRAGCOORD
// (actual framebuffer pixels) and derive the scale factor from
// SCREEN_PIXEL_SIZE.
uniform float chunk_size_in_reference : hint_range(0.5, 8.0) = 1.0;

const float REFERENCE_WIDTH = 640.0;

// JPEG-style static — soft chunks with sub-pixel gradients. Each reference
// pixel gets a base noise value plus an internal directional gradient, so
// HD pixels inside the chunk vary smoothly — reads as "compressed image
// with sub-pixel detail," not nearest-neighbor blockiness.
uniform float static_strength : hint_range(0.0, 1.0) = 0.0;
uniform float static_rate : hint_range(1.0, 60.0) = 8.0;
uniform float static_intra_chunk : hint_range(0.0, 1.0) = 0.15;

// Flicker (chunk masking) lives on hd_portrait_mask.gdshader instead — see
// the note in the fragment body. The overlay can only modulate; cutting
// requires a shader on the mirror itself.


// David Hoskins-style hash. Avoids the sin-based hash's non-uniform
// distribution at large inputs (see hd_portrait_mask.gdshader for the
// detailed reasoning — same issue applies to the static effect here).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p, 1.0) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash_seeded(vec2 p, float seed) {
	vec3 p3 = fract(vec3(p, seed) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	vec4 base = COLOR;

	// Skip fully-transparent pixels — outside the StyleBoxFlat's drawn region.
	// Without this guard the effect would expand the panel's apparent rect.
	if (base.a < 0.01) {
		COLOR = base;
	} else {
		// 1. Tint toward glass color
		vec3 tinted = mix(base.rgb, glass_tint.rgb, glass_tint.a);

		// 2. Top-down gradient — top a bit brighter, bottom a bit dimmer.
		float gradient = mix(1.0 + gradient_strength, 1.0 - gradient_strength * 0.5, UV.y);
		tinted *= gradient;

		// 3. Top-edge highlight — quick falloff from the top edge.
		float highlight = pow(max(0.0, 1.0 - UV.y * top_highlight_falloff), 2.0) * top_highlight_strength;
		tinted = mix(tinted, highlight_color.rgb, highlight);

		// 4. Scanlines — sin-wave horizontal darkening, mixed in by strength.
		// Subtracting (TIME * speed) from UV.y shifts the pattern downward as
		// time advances (positive speed → features that were at y_0 at t=0 are
		// at y_0 + speed*dt at t=dt). Negative speed scrolls upward.
		float scan_y = (UV.y - TIME * scanline_speed) * scanline_density;
		if (scanline_strength > 0.0) {
			float scan = sin(scan_y);
			float scan_factor = mix(1.0, 0.5 + scan * 0.5, scanline_strength);
			tinted *= scan_factor;
		}

		// 5. Every Nth scanline accent — sinusoidal brightening confined to
		// rows whose scanline index is a multiple of `accent_every`. The
		// `0.15915` is 1/(2π), converting phase to integer cycle index.
		if (accent_strength > 0.0) {
			int scan_idx = int(floor(scan_y * 0.15915));
			if (int(mod(float(scan_idx), accent_every)) == 0) {
				float local = scan_y - float(scan_idx) * 6.2832;
				float band = sin(local) * 0.5 + 0.5;
				tinted *= 1.0 + band * accent_strength;
			}
		}

		// Reference-pixel quantization via FRAGCOORD. Scale factor (actual
		// screen pixels per reference pixel) is derived from
		// SCREEN_PIXEL_SIZE — independent of UV remapping, AtlasTexture
		// regions, KEEP_ASPECT padding, etc. Chunks are always square at
		// the requested reference resolution.
		float scale_factor = (1.0 / SCREEN_PIXEL_SIZE.x) / REFERENCE_WIDTH;
		float chunk_pixel_size = max(1.0, chunk_size_in_reference * scale_factor);
		vec2 ref_coord = floor(FRAGCOORD.xy / chunk_pixel_size);
		vec2 sub_coord = fract(FRAGCOORD.xy / chunk_pixel_size) - 0.5;

		// 6. JPEG-style static — chunk base value + intra-chunk gradient.
		// Time is fed to the hash as an INDEPENDENT seed (not as a coord
		// offset), so each time bucket produces uncorrelated noise instead of
		// a pattern that appears to scroll sideways frame-to-frame.
		if (static_strength > 0.0) {
			float t_bucket = floor(TIME * static_rate);
			float chunk_value = hash_seeded(ref_coord, t_bucket);
			vec2 gradient_dir = vec2(
				hash_seeded(ref_coord, t_bucket + 7.1),
				hash_seeded(ref_coord, t_bucket + 13.7)
			) * 2.0 - 1.0;
			float intra = dot(sub_coord, gradient_dir) * static_intra_chunk;
			float final_noise = chunk_value + intra;
			tinted *= mix(1.0, final_noise * 2.0, static_strength);
		}

		// Pixel-chunk flicker that punches holes in the line art lives on a
		// separate mask shader (see hd_portrait_mask.gdshader) — applied to
		// the HD mirror, not this overlay. The overlay can only modulate
		// color, not erase line art behind it.

		COLOR = vec4(tinted, base.a);
	}
}
