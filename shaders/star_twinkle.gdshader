shader_type canvas_item;

// Twinkle for a painted STAR MAP: every opaque non-black texel is one star.
//   R   X-shaped tails, brightness = reach
//   G   +-shaped tails, brightness = reach
//   R+G alternates X and + flash to flash (white = alternating, fastest)
//   B   cadence: 0 flashes rarely, 255 nearly constantly
//   B alone: a bare core that blinks
// Tails reach at most 3 px, so a star's footprint is 7×7 and each fragment
// gathers the 49 texels around it. Only star_color ever leaves this shader;
// the map's own colors are data. Near-black is "no star" and renders
// TRANSPARENT — the sky background is a layer underneath, not this one.
//
// Between the [shared] markers is plain GLSL ES 3.00 with no Godot built-ins:
// data/design/mockups/skybox_twinkle_lab.html embeds it verbatim so Lawrence
// tunes the real shader. Keep TEXTURE / UV / TIME / COLOR / hints outside.

// The node's own texture again, as a uniform: built-ins can't be read inside
// a function, and handing TEXTURE in as an argument fails on the headless
// renderer. StarSky sets it; a bare material draws nothing.
uniform sampler2D star_map : filter_nearest, repeat_disable;
uniform vec4 star_color : source_color = vec4(0.93, 0.93, 0.89, 1.0);
// 0 parks every star at rest (the ui_motion_enabled hook); 1 = as painted.
uniform float twinkle_amount : hint_range(0.0, 1.0) = 1.0;
// time = TIME * time_scale + time_offset. Scale 0 freezes the sky at the
// offset — deterministic frames for probes and tests.
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;
uniform float time_offset = 0.0;
// A flash rises over half of flash_seconds, holds full reach for
// hold_seconds, then falls over the other half. The painted blue picks the
// period between flashes (slow at 0, fast at 255); period_jitter spreads it
// ± per star so neighbors never sync.
uniform float flash_seconds : hint_range(0.1, 3.0) = 0.6;
uniform float hold_seconds : hint_range(0.0, 3.0) = 0.0;
uniform float period_slow_seconds : hint_range(0.5, 30.0) = 8.0;
uniform float period_fast_seconds : hint_range(0.5, 30.0) = 1.5;
uniform float period_jitter : hint_range(0.0, 0.5) = 0.2;
// Time is stepped to this many ticks per second so the motion reads as
// hand-animated pixel art. 0 = smooth.
uniform float frame_rate : hint_range(0.0, 60.0) = 12.0;
// Alpha of a tail's TIP pixel. Pixels behind the tip brighten one step per
// pixel of depth, so a tail fades in from the outside as it grows instead of
// popping in at full — and dims the same way as it retracts.
uniform float tail_tip_alpha : hint_range(0.0, 1.0) = 0.35;
// Core alpha at rest runs from this (dimmest painted star) up to 1 (#FF).
uniform float rest_alpha_min : hint_range(0.0, 1.0) = 0.1;

varying vec4 vertex_modulate;


void vertex() {
	vertex_modulate = COLOR;
}


// [shared-begin]
const int MAX_REACH = 3;
const float STAR_THRESHOLD = 0.02;


// Stable per-star random in [0, 1) from the texel coordinate.
float star_hash(ivec2 cell, uint salt) {
	uint h = uint(cell.x + 4096) * 374761393u
			+ uint(cell.y + 4096) * 668265263u
			+ salt * 2246822519u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h & 0x00FFFFFFu) / 16777215.0;
}


// Steps time to frame_rate ticks per second; 0 leaves it smooth.
float quantize_time(float t) {
	return frame_rate > 0.0 ? floor(t * frame_rate) / frame_rate : t;
}


// x: the star's swell — 0 → 1 rising, 1 through the hold, 1 → 0 falling —
//    or -1 while it rests.
// y: the flash's ordinal; its parity alternates a two-shape star.
vec2 flash_state(ivec2 cell, float cadence, float t) {
	float period = mix(period_slow_seconds, period_fast_seconds, cadence)
			* mix(1.0 - period_jitter, 1.0 + period_jitter, star_hash(cell, 1u));
	float clock = t + star_hash(cell, 2u) * period;
	float index = floor(clock / period);
	float local_time = clock - index * period;
	float half_flash = flash_seconds * 0.5;
	float swell = -1.0;
	if (local_time < half_flash) {
		swell = sin(0.5 * PI * local_time / half_flash);
	} else if (local_time < half_flash + hold_seconds) {
		swell = 1.0;
	} else if (local_time < flash_seconds + hold_seconds) {
		swell = sin(0.5 * PI * (1.0 - (local_time - half_flash - hold_seconds) / half_flash));
	}
	return vec2(swell, index);
}


// k = distance from the core, reach = the tail's current length.
float tail_alpha(int k, int reach) {
	float depth = float(reach - k) / float(MAX_REACH - 1);
	return mix(tail_tip_alpha, 1.0, depth);
}


// Alpha this star contributes at `offset` (fragment texel − star texel).
float star_alpha(ivec2 cell, vec3 channels, ivec2 offset, float t) {
	vec2 state = flash_state(cell, channels.b, t);
	bool resting = state.x < 0.0;
	float swell = max(state.x, 0.0);
	float intensity = max(channels.r, channels.g);
	ivec2 a = abs(offset);

	if (offset == ivec2(0)) {
		// A blue-only star has no reach, so its whole twinkle is this flare.
		float rest = mix(rest_alpha_min, 1.0, intensity);
		return mix(rest, 1.0, swell * twinkle_amount);
	}
	if (resting) {
		return 0.0;
	}
	bool has_x = channels.r > STAR_THRESHOLD;
	bool has_plus = channels.g > STAR_THRESHOLD;
	bool odd_flash = mod(state.y, 2.0) >= 1.0;
	if (has_x && !(has_plus && odd_flash) && a.x == a.y) {
		int reach = int(round(swell * channels.r * float(MAX_REACH) * twinkle_amount));
		return a.x <= reach ? tail_alpha(a.x, reach) : 0.0;
	}
	if (has_plus && !(has_x && !odd_flash) && min(a.x, a.y) == 0) {
		int k = max(a.x, a.y);
		int reach = int(round(swell * channels.g * float(MAX_REACH) * twinkle_amount));
		return k <= reach ? tail_alpha(k, reach) : 0.0;
	}
	return 0.0;
}


// Alpha of the star layer at `cell`: the strongest contribution from any
// star within reach. Transparent and near-black texels are not stars.
float sky_alpha(ivec2 cell, float t) {
	ivec2 map_size = textureSize(star_map, 0);
	float alpha = 0.0;
	for (int dy = -MAX_REACH; dy <= MAX_REACH; dy++) {
		for (int dx = -MAX_REACH; dx <= MAX_REACH; dx++) {
			ivec2 star = cell + ivec2(dx, dy);
			if (any(lessThan(star, ivec2(0))) || any(greaterThanEqual(star, map_size))) {
				continue;
			}
			vec4 texel = texelFetch(star_map, star, 0);
			if (texel.a < 0.5 || max(texel.r, max(texel.g, texel.b)) < STAR_THRESHOLD) {
				continue;
			}
			alpha = max(alpha, star_alpha(star, texel.rgb, -ivec2(dx, dy), t));
		}
	}
	return alpha;
}
// [shared-end]


void fragment() {
	ivec2 cell = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	float t = quantize_time(TIME * time_scale + time_offset);
	COLOR = vec4(star_color.rgb, star_color.a * sky_alpha(cell, t)) * vertex_modulate;
}
