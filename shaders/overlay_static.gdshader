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

uniform float static_strength : hint_range(0.0, 1.0) = 0.35;
uniform float static_rate : hint_range(1.0, 60.0) = 8.0;
uniform float chunk_size_in_reference : hint_range(0.5, 8.0) = 1.0;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_period_px : hint_range(1.0, 16.0) = 3.0;

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

	if (scanline_strength > 0.0) {
		float scan = sin(world_px.y * 6.2832 / scanline_period_px) * 0.5 + 0.5;
		tint.a *= mix(1.0, scan, scanline_strength);
	}

	if (static_strength > 0.0) {
		float scale_factor = (1.0 / SCREEN_PIXEL_SIZE.x) / REFERENCE_WIDTH;
		float chunk_pixel_size = max(1.0, chunk_size_in_reference * scale_factor);
		vec2 ref_coord = floor(FRAGCOORD.xy / chunk_pixel_size);
		float t_bucket = floor(TIME * static_rate) * animate;
		float n = hash_seeded(ref_coord, t_bucket);
		// Upper half of the hash = sparkle (lift toward white + thicken the
		// fill); lower half thins it. Mirrors the portrait static's "bright
		// chunks being added" read without needing blend_add.
		float sparkle = max(0.0, n - 0.5) * 2.0 * static_strength;
		float thin = max(0.0, 0.5 - n) * 2.0 * static_strength;
		tint.rgb = mix(tint.rgb, vec3(1.0), sparkle * 0.6);
		tint.a *= 1.0 + sparkle * 0.5 - thin * 0.35;
	}

	COLOR = tint;
}
