// Projection-static for grid overlay decals (threat zones, pinned zones, the
// move-range live-paint). Adapted from the HD portraits' glass_panel.gdshader
// static + scanline passes (RQD/Lawrence 2026-07-30 — "apply the static shader
// we use for the highres portraits to all of these overlays; tune the static
// down"). IN-GAME TRIAL — defaults are deliberately visible for the eyeball;
// tune in resources/overlay_static.tres.
//
// The portrait overlay is blend_add light over line art; these decals are
// alpha-blended tints over the board, so the passes are reformulated to
// modulate the decal's own color/alpha instead of adding light:
//   • Static — per-chunk hash per time bucket: the upper half of the
//     distribution lifts the chunk toward white and thickens its alpha, the
//     lower half thins the fill — the tint shimmers like a weak projection.
//   • Scanlines — sin troughs thin the fill in WORLD-pixel rows, so the
//     stripes ride the board (and stay put under camera pans), not the window.
// Chunks are quantized at reference resolution (640×360) exactly like the
// portrait static, so the grain size is zoom-stable.
shader_type canvas_item;

uniform float static_strength : hint_range(0.0, 1.0) = 0.6;
uniform float static_rate : hint_range(1.0, 60.0) = 8.0;
uniform float chunk_size_in_reference : hint_range(0.5, 8.0) = 1.0;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_period_px : hint_range(1.0, 16.0) = 3.0;
// Scroll drift in world px/sec (positive = downward), matching the portrait
// glass whose scanlines crawl (RQD 2026-07-31: "doesn't scroll like it does
// on the portraits").
uniform float scanline_speed_px : hint_range(-30.0, 30.0) = 3.0;

// === VHS tracking band (hd_portrait_tracking, reformulated for decals) ===
// The portrait version re-samples the line art at displaced UVs; a flat tint
// has nothing to resample, so the band TEARS the static chunks sideways and
// pumps the fill's brightness/alpha as it sweeps past — same read, decal
// dialect. Bands ride WORLD y (they sweep the board, not the window).
uniform float tracking_strength : hint_range(0.0, 1.0) = 0.5;
uniform float tracking_band_height_px : hint_range(1.0, 64.0) = 10.0;
uniform float tracking_speed_px : hint_range(-120.0, 120.0) = -24.0;
uniform float tracking_period_px : hint_range(16.0, 512.0) = 120.0;
uniform float tracking_shift_chunks : hint_range(0.0, 8.0) = 2.0;
uniform float tracking_noise_rate : hint_range(1.0, 120.0) = 30.0;

// Settings.ui_motion_enabled mirror — ThreatOverlayRenderer sets this. 0
// freezes the static's time bucket: the texture keeps its color, loses its
// flicker (the reduce-motion contract).
uniform float animate : hint_range(0.0, 1.0) = 1.0;

const float REFERENCE_WIDTH = 640.0;

varying vec2 world_px;


void vertex() {
	// The renderer sits at identity transform, so local coords ARE world
	// pixels — the stable grid the scanlines lock to.
	world_px = VERTEX;
}


// David Hoskins hash — same constants and rationale as glass_panel.gdshader
// (uniform distribution, no sin-precision issues at large coords).
float hash_seeded(vec2 p, float seed) {
	vec3 p3 = fract(vec3(p, seed) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	vec4 tint = COLOR;
	// Reduce-motion (animate = 0) freezes every clock at once: scanlines
	// stop crawling, bands park, static stops re-rolling — color stays.
	float t = TIME * animate;

	if (scanline_strength > 0.0) {
		float scan = sin((world_px.y - t * scanline_speed_px) * 6.2832 / scanline_period_px)
				* 0.5 + 0.5;
		tint.a *= mix(1.0, scan, scanline_strength);
	}

	// Tracking band influence: 1.0 at a band's center, 0.0 past half the
	// band height. Same modular-arithmetic band field as the portrait
	// tracking shader, in world pixels.
	float band_influence = 0.0;
	if (tracking_strength > 0.0) {
		float phase = mod(world_px.y - t * tracking_speed_px, tracking_period_px);
		phase = mod(phase + tracking_period_px, tracking_period_px);
		float dist_to_band = min(phase, tracking_period_px - phase);
		band_influence = smoothstep(tracking_band_height_px * 0.5, 0.0, dist_to_band);
	}

	if (static_strength > 0.0) {
		float scale_factor = (1.0 / SCREEN_PIXEL_SIZE.x) / REFERENCE_WIDTH;
		float chunk_pixel_size = max(1.0, chunk_size_in_reference * scale_factor);
		vec2 ref_coord = floor(FRAGCOORD.xy / chunk_pixel_size);
		// The band's horizontal tear: whole chunk-rows shift sideways while
		// the band passes (the decal version of the portraits' row-displaced
		// UV sampling).
		if (band_influence > 0.0) {
			float row_noise = hash_seeded(vec2(ref_coord.y, floor(t * tracking_noise_rate)), 51.3);
			ref_coord.x += round((row_noise * 2.0 - 1.0) * tracking_shift_chunks * band_influence);
		}
		float t_bucket = floor(t * static_rate);
		float n = hash_seeded(ref_coord, t_bucket);
		// Top of the hash distribution = sparkle (lift toward white +
		// thicken the fill); bottom = the fill drops toward transparent —
		// flickering holes read as static far better than brightness
		// wobble on a low-alpha decal. Mirrors the portrait static's
		// "bright chunks being added" without needing blend_add.
		float sparkle = clamp(max(0.0, n - 0.6) * 2.5 * static_strength, 0.0, 1.0);
		float thin = clamp(max(0.0, 0.45 - n) * 2.2 * static_strength, 0.0, 1.0);
		tint.rgb = mix(tint.rgb, vec3(1.0), sparkle * 0.7);
		tint.a *= clamp(1.0 + sparkle * 0.9 - thin * 0.9, 0.0, 2.0);
	}

	// The band itself pumps the fill — the "video signal spike" the portrait
	// shader sells with tracking_band_brightness.
	if (band_influence > 0.0) {
		tint.rgb = mix(tint.rgb, vec3(1.0), band_influence * tracking_strength * 0.25);
		tint.a *= 1.0 + band_influence * tracking_strength * 0.5;
	}

	COLOR = tint;
}
