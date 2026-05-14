// Projection-style effect overlay for HD portraits. Applied to a ColorRect
// in HDLayer that sits above the HD line art mirror.
//
// PROJECTION MODEL (vs the old occlusion model):
//   • `render_mode blend_add` — the shader's RGB output is ADDED to the
//     line art behind, never multiplied or alpha-blended over. The line
//     art's native brightness is always preserved as a minimum; this
//     shader can only ADD light, never subtract.
//   • Each pass outputs a positive "light contribution." Outputs of
//     ~zero leave the line art untouched; positive values brighten it
//     and shift its tone toward the contribution's color.
//   • Effects that used to multiply pixels downward (darkening troughs,
//     dot punches) are reformulated: scanline troughs simply contribute
//     no light, dot chunks contribute a bright colored pulse instead of
//     darkening.
//
// The pixel-art panel that hosts the line art continues to be visible —
// only the line art itself is brightened by this overlay.
shader_type canvas_item;
render_mode blend_add;


// Ambient projection light — adds a constant tint to the entire portrait
// area. Default zero so nothing is added until you push the alpha up.
// RGB is the tint color, alpha is the strength of the contribution.
uniform vec4 overlay_base : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// Color of the projector's "lamp" — the dominant light contribution that
// other passes mix toward. Alpha scales how strongly this lamp light is
// applied as ambient projection.
uniform vec4 glass_tint : source_color = vec4(0.298, 0.549, 0.733, 0.1);   // Azure 5
uniform vec4 highlight_color : source_color = vec4(0.859, 0.953, 1.0, 1.0); // Azure 9


// === Gradient and edge highlight ===
// Both are additive: positive light brightening toward the top.
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.0;
uniform float top_highlight_strength : hint_range(0.0, 1.0) = 0.15;
uniform float top_highlight_falloff : hint_range(1.0, 16.0) = 4.0;


// === Scanlines ===
// Bright horizontal bands; sin peaks contribute light, troughs contribute
// zero. Scrolls vertically at scanline_speed.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.1;
uniform float scanline_density : hint_range(10.0, 300.0) = 60.0;
uniform float scanline_speed : hint_range(-2.0, 2.0) = 0.05;


// === Every-Nth-scanline accent ===
// Adds a brighter band on rows whose scanline index is a multiple of
// `accent_every`. Setting accent_strength = 0 or accent_every = 0 disables.
uniform float accent_every : hint_range(0.0, 64.0) = 32.0;
uniform float accent_strength : hint_range(0.0, 2.0) = 0.0;


// === Reference-resolution chunk effects ===
// Static and dot use FRAGCOORD-quantized chunks at reference resolution
// (640×360). Same chunk math is independent of UV/atlas/aspect issues.
uniform float chunk_size_in_reference : hint_range(0.5, 8.0) = 1.0;

const float REFERENCE_WIDTH = 640.0;


// === Static noise — bright sparkles ===
// Each chunk gets a hash-driven brightness value per time bucket; only the
// upper half of the distribution contributes light (lower half = zero),
// so the effect reads as "sparkles being added" rather than "noise both
// brightening and dimming the image."
uniform float static_strength : hint_range(0.0, 1.0) = 0.0;
uniform float static_rate : hint_range(1.0, 60.0) = 8.0;
uniform float static_intra_chunk : hint_range(0.0, 1.0) = 0.15;


// === Bright dot glitch ===
// Sparse chunks pulse a colored light contribution — reads as "scanner
// dropout glitch" rather than "missing pixel." dot_color is the color of
// the glitch (default bright Azure 9). For actual pixel cuts in the line
// art, you'd need a separate mask shader on the mirror itself.
uniform vec4 dot_color : source_color = vec4(0.859, 0.953, 1.0, 1.0);
uniform float dot_strength : hint_range(0.0, 1.0) = 0.0;
uniform float dot_chance : hint_range(0.0, 0.05, 0.00001) = 0.0001;
uniform float dot_rate : hint_range(1.0, 60.0) = 4.0;


// David Hoskins hash — uniform across the input range, no sin-precision
// issues at large FRAGCOORD values. Per-component multipliers (0.1031,
// 0.1030, 0.0973) are the canonical Hoskins constants; they break
// correlations between input axes. Using a single shared multiplier here
// (as the earlier version did) produces a distribution that's biased at
// the very-low-output end — which inflates trigger rates for sub-0.001
// thresholds like `dot_chance` by an order of magnitude.
float hash_seeded(vec2 p, float seed) {
	vec3 p3 = fract(vec3(p, seed) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	// Each pass appends a positive RGB contribution. Final COLOR.rgb is
	// added to the line art behind; COLOR.a = 1 means full contribution
	// (blend_add adds src.rgb * src.a to dst).
	vec3 light = vec3(0.0);

	// 1. Ambient — flat tint applied everywhere.
	light += overlay_base.rgb * overlay_base.a;

	// 2. Lamp tint — overall projection lamp color contribution.
	light += glass_tint.rgb * glass_tint.a;

	// 3. Top-down gradient — extra brightness near the top, fading to
	// zero at the bottom. Tinted with glass_tint so the gradient shifts
	// hue toward the lamp color instead of just adding white (which
	// would desaturate the line art beneath).
	light += glass_tint.rgb * mix(gradient_strength, 0.0, UV.y);

	// 4. Sharp top-edge highlight — Azure 9 (or whatever highlight_color
	// is) ramping in quickly from the top edge. Pow2 of a clamped UV
	// gradient gives a clean falloff.
	float highlight = pow(max(0.0, 1.0 - UV.y * top_highlight_falloff), 2.0) * top_highlight_strength;
	light += highlight_color.rgb * highlight;

	// 5. Scanlines — bright bands at sin peaks. max(0, sin) clamps the
	// trough half to zero so it contributes no light, leaving the line
	// art at its base brightness between bands.
	float scan_y = (UV.y - TIME * scanline_speed) * scanline_density;
	if (scanline_strength > 0.0) {
		float scan = max(0.0, sin(scan_y));
		// Tint the scanlines with the lamp color so they read as part of
		// the same projection rather than as white-only stripes.
		light += glass_tint.rgb * scan * scanline_strength;
	}

	// 6. Every Nth scanline accent — extra-bright row, lamp-tinted.
	if (accent_strength > 0.0 && accent_every >= 1.0) {
		int scan_idx = int(floor(scan_y * 0.15915));
		if (int(mod(float(scan_idx), accent_every)) == 0) {
			float local = scan_y - float(scan_idx) * 6.2832;
			float band = sin(local) * 0.5 + 0.5;
			light += highlight_color.rgb * band * accent_strength;
		}
	}

	// Reference-pixel quantization for chunk-based effects.
	float scale_factor = (1.0 / SCREEN_PIXEL_SIZE.x) / REFERENCE_WIDTH;
	float chunk_pixel_size = max(1.0, chunk_size_in_reference * scale_factor);
	vec2 ref_coord = floor(FRAGCOORD.xy / chunk_pixel_size);
	vec2 sub_coord = fract(FRAGCOORD.xy / chunk_pixel_size) - 0.5;

	// 7. Static — bright sparkles. Hash gives a value in [0,1] per chunk
	// per time bucket; we use `max(0, n - 0.5) * 2` to take only the
	// upper half of the distribution, so the effect reads as "bright
	// chunks being added" not "noise modulating brightness up and down."
	if (static_strength > 0.0) {
		float t_bucket = floor(TIME * static_rate);
		float chunk_value = hash_seeded(ref_coord, t_bucket);
		vec2 gradient_dir = vec2(
			hash_seeded(ref_coord, t_bucket + 7.1),
			hash_seeded(ref_coord, t_bucket + 13.7)
		) * 2.0 - 1.0;
		float intra = dot(sub_coord, gradient_dir) * static_intra_chunk;
		float final_noise = chunk_value + intra;
		float bright = max(0.0, final_noise - 0.5) * 2.0 * static_strength;
		// Sparkles tinted with the lamp color so they read as part of the
		// projection's energy, preserving the projector's hue. No pure-white
		// component — that just desaturates everything underneath.
		light += glass_tint.rgb * bright;
	}

	// 8. Bright dot glitch — sparse chunks add a strong color pulse,
	// like a scanner dropout dropping a bright square instead of a hole.
	//
	// Uses TWO independent hashes and requires both to pass `sqrt(chance)`.
	// Single-hash trigger at sub-0.001 thresholds was firing ~25× over the
	// expected rate due to the Hoskins hash's low-tail bias; combining two
	// independent hashes effectively squares the threshold and dilutes any
	// single-hash bias against the other's normal distribution, so the
	// effective probability matches `dot_chance` accurately.
	if (dot_strength > 0.0) {
		float dot_bucket = floor(TIME * dot_rate);
		float h1 = hash_seeded(ref_coord, dot_bucket + 91.7);
		float h2 = hash_seeded(ref_coord, dot_bucket + 137.3);
		float threshold = sqrt(max(0.0, dot_chance));
		if (h1 < threshold && h2 < threshold) {
			light += dot_color.rgb * dot_strength;
		}
	}

	COLOR = vec4(light, 1.0);
}
