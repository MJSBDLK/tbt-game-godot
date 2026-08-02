// Ghost-projection for the displacement preview: flattens a unit's live
// sprite frame to a tinted SILHOUETTE, then runs the same projection passes
// as the grid decals so the ghost reads as "a projection of the future" in
// the established glass identity (RQD 2026-08-01: tracking confirmed good at
// world scale on the targeting range).
//
// The scanline/tracking/static passes are DUPLICATED from
// overlay_static.gdshader (that shader modulates a flat decal COLOR; this one
// needs the sprite texture's alpha first, and its nodes carry real transforms
// so world_px comes from MODEL_MATRIX, not identity-parent VERTEX). If you
// retune one, retune both — same knob names on purpose.
//
// Blink rides the node's modulate alpha (COLOR.a here = texture.a × modulate.a),
// so one shared material serves every ghost.
shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.42, 0.76, 0.87, 0.6);

uniform float static_strength : hint_range(0.0, 1.0) = 0.6;
uniform float static_rate : hint_range(1.0, 60.0) = 8.0;
uniform float chunk_size_in_reference : hint_range(0.5, 8.0) = 1.0;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_period_px : hint_range(1.0, 16.0) = 3.0;
uniform float scanline_speed_px : hint_range(-30.0, 30.0) = 3.0;

uniform float tracking_strength : hint_range(0.0, 1.0) = 0.5;
uniform float tracking_band_height_px : hint_range(1.0, 64.0) = 10.0;
uniform float tracking_speed_px : hint_range(-120.0, 120.0) = -24.0;
uniform float tracking_period_px : hint_range(16.0, 512.0) = 120.0;
uniform float tracking_shift_chunks : hint_range(0.0, 8.0) = 2.0;
uniform float tracking_noise_rate : hint_range(1.0, 120.0) = 30.0;

// Settings.ui_motion_enabled mirror — the renderer sets this. 0 freezes every
// clock: the ghost keeps its texture, loses its flicker.
uniform float animate : hint_range(0.0, 1.0) = 1.0;

const float REFERENCE_WIDTH = 640.0;

varying vec2 world_px;


void vertex() {
	// Ghost sprites carry real transforms (they sit on board cells), so world
	// pixels come from the model matrix — unlike the decal renderers, whose
	// identity parents let VERTEX stand in for world coords.
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


float hash_seeded(vec2 p, float seed) {
	vec3 p3 = fract(vec3(p, seed) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	// Silhouette flatten: COLOR.a at entry = texture alpha × modulate alpha
	// (blink), COLOR.rgb is discarded — the ghost is pure tint.
	vec4 tint = vec4(tint_color.rgb, COLOR.a * tint_color.a);
	float t = TIME * animate;

	if (scanline_strength > 0.0) {
		float scan = sin((world_px.y - t * scanline_speed_px) * 6.2832 / scanline_period_px)
				* 0.5 + 0.5;
		tint.a *= mix(1.0, scan, scanline_strength);
	}

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
		if (band_influence > 0.0) {
			float row_noise = hash_seeded(vec2(ref_coord.y, floor(t * tracking_noise_rate)), 51.3);
			ref_coord.x += round((row_noise * 2.0 - 1.0) * tracking_shift_chunks * band_influence);
		}
		float t_bucket = floor(t * static_rate);
		float n = hash_seeded(ref_coord, t_bucket);
		float sparkle = clamp(max(0.0, n - 0.6) * 2.5 * static_strength, 0.0, 1.0);
		float thin = clamp(max(0.0, 0.45 - n) * 2.2 * static_strength, 0.0, 1.0);
		tint.rgb = mix(tint.rgb, vec3(1.0), sparkle * 0.7);
		tint.a *= clamp(1.0 + sparkle * 0.9 - thin * 0.9, 0.0, 2.0);
	}

	if (band_influence > 0.0) {
		tint.rgb = mix(tint.rgb, vec3(1.0), band_influence * tracking_strength * 0.25);
		tint.a *= 1.0 + band_influence * tracking_strength * 0.5;
	}

	COLOR = tint;
}
