// VHS-style tracking error effect for the HD portrait line art. Applied to
// the HD mirror via HDPortraitSlot.projection_material.
//
// A horizontal band scrolls vertically through the portrait. Inside the
// band, each horizontal row of pixels gets a noise-driven horizontal
// offset before texture sampling — reads as torn / jittery image content,
// like a VHS tape with bad tracking.
//
// This is the rare effect that legitimately requires shadering the mirror
// (rather than just the overlay above it) — the overlay can only modulate
// color and alpha on top of the line art, but tracking distortion needs to
// actually re-sample the line art at displaced UVs to produce tearing.
shader_type canvas_item;

// Vertical thickness of the tracking band in UV space (0..1 across the
// slot's height). 0.08 = 8% of slot height — fairly thin tear.
uniform float tracking_band_height : hint_range(0.001, 0.5) = 0.08;

// Maximum horizontal UV displacement within the band. 0.02 = up to 2% of
// the slot's width per row. Set to 0 to disable the effect entirely.
uniform float tracking_strength : hint_range(0.0, 0.1) = 0.0;

// Band scroll velocity in UV-per-second when the band is active. Negative
// = upward (the more classic VHS direction). 0 = static band. Inspector
// accepts typed values past the slider range if you ever need to go
// faster than 1 UV/sec.
uniform float tracking_speed : hint_range(-1.0, 1.0) = -0.3;

// Spawn-rate semantics: how many seconds between new bands appearing.
// 0 = continuous single-band mode (band scrolls and wraps at slot edges).
// >0 = multi-band: a new band spawns every `period` seconds, moving at
// `tracking_speed`. From any pixel's perspective, a band passes by every
// `period` seconds regardless of how slow the speed is.
//
// Behavior emerges from speed × period:
//   speed × period < 1 → multiple bands visible at once (stacked stripes)
//   speed × period ≈ 1 → exactly one band visible, no gap (continuous feel)
//   speed × period > 1 → one band visible with dormant gaps between sweeps
//
// Examples:
//   period=1, speed=0.05 → bands every 1s, ~20 stacked at once (dense)
//   period=1, speed=1.0  → 1 band sweeps slot in 1s, no gap
//   period=4, speed=1.0  → 1 band sweeps in 1s, 3s dormant gap, repeat
//   period=2, speed=0.5  → 1 band sweeps in 2s, no gap
uniform float tracking_period : hint_range(0.0, 30.0) = 0.0;

// Rate at which per-row noise re-rolls (Hz). Higher = more jittery /
// chaotic; lower = each row's displacement lingers as the band passes.
uniform float tracking_noise_rate : hint_range(1.0, 120.0) = 30.0;

// Granularity of the displacement — how many noise rows per UV unit. At
// 100 rows on a 96-reference slot you get ~roughly-pixel-aligned noise.
uniform float tracking_row_density : hint_range(20.0, 400.0) = 100.0;

// Optional brightness lift inside the band — sells the "video signal
// spike" feel. 0 = no brightness change.
uniform float tracking_band_brightness : hint_range(0.0, 1.0) = 0.0;

// Gamma adjustment for the line art (NOT linear multiplication — that
// just clips highlights and washes saturation). 1.0 = unchanged, >1
// lifts shadows toward midtones (image looks brighter, dark areas
// brighten more than light areas), <1 deepens shadows. Use this to
// compensate for the glass overlay's darkening passes (especially the
// static, whose noise modulation pulls roughly half the pixels below
// baseline). Inspector accepts typed values past the slider range.
uniform float lineart_gamma : hint_range(0.2, 2.5) = 1.0;


// David Hoskins hash — uniform across the input domain, no sin precision
// issues at large coords. Per-component multipliers (0.1031, 0.1030,
// 0.0973) are the canonical Hoskins constants — they break correlations
// between input axes that otherwise bias the distribution at the
// low-output end.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p, 1.0) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	// Compute distance from this pixel to the nearest band.
	//
	// Two modes:
	//   • period <= 0: single continuous band that wraps at the slot edges.
	//   • period > 0:  multi-band — bands stream past at `period` Hz,
	//     spaced `period * |speed|` UV apart in the moving reference frame.
	//     Distance to nearest band is computed via modular arithmetic in
	//     that frame, which naturally handles "multiple bands stacked"
	//     (slow speed) and "one band with gaps" (fast speed) without
	//     needing separate code paths.
	float dist_to_band;
	if (tracking_period <= 0.0) {
		float band_y = fract(TIME * tracking_speed);
		dist_to_band = abs(UV.y - band_y);
		dist_to_band = min(dist_to_band, 1.0 - dist_to_band);
	} else {
		// `spatial_period` is the UV spacing between consecutive bands.
		// Guard against 0 (would be infinite bands at the same spot).
		float spatial_period = max(0.0001, tracking_period * abs(tracking_speed));
		// In the moving frame, the pattern is stationary. The pixel's
		// position within one tile of the pattern is its phase.
		float phase = mod(UV.y - TIME * tracking_speed, spatial_period);
		// GLSL `mod` can return negative for negative inputs — normalize.
		phase = mod(phase + spatial_period, spatial_period);
		dist_to_band = min(phase, spatial_period - phase);
	}

	// Smooth falloff: 1.0 at a band's center, 0.0 once we're more than
	// half the band height away from any band.
	float band_influence = smoothstep(tracking_band_height * 0.5, 0.0, dist_to_band);

	// Per-row noise — quantize UV.y into rows so an entire horizontal
	// scanline shifts together (otherwise it'd just look like static).
	// Time also bucketed so the noise updates at tracking_noise_rate Hz.
	float row_idx = floor(UV.y * tracking_row_density);
	float t_bucket = floor(TIME * tracking_noise_rate);
	float row_noise = hash(vec2(row_idx, t_bucket));

	// Map noise 0..1 → -1..1, scale by strength and influence. Outside
	// the band, influence ≈ 0 → no displacement.
	float displace = (row_noise * 2.0 - 1.0) * tracking_strength * band_influence;

	vec2 displaced_uv = UV + vec2(displace, 0.0);
	vec4 src = texture(TEXTURE, displaced_uv);

	// Gamma adjustment — `pow(rgb, 1/gamma)`. With gamma > 1, mid-grays
	// lift toward white (image looks brighter), while pure-black stays
	// black and pure-white stays white. Preserves dynamic range better
	// than a linear multiplier, which would clip highlights and shift
	// hue at the clip points.
	src.rgb = pow(max(src.rgb, vec3(0.0)), vec3(1.0 / max(0.05, lineart_gamma)));

	// Optional brightness pump inside the band.
	if (tracking_band_brightness > 0.0) {
		src.rgb *= 1.0 + tracking_band_brightness * band_influence;
	}

	COLOR = src;
}
