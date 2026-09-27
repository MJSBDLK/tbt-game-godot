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
// A flash is hand-animated frames: tails grow one pixel per frame and pull
// back the same way (1, 2, 3, 2, 1), every frame step_seconds long; the two
// holds add time at full reach and at 1 px (see flash_reach). Frame lengths
// come straight from time — rounding an eased curve to whole pixels leaves
// the full-reach frame lingering. The painted blue picks the period between
// flashes (slow at 0, fast at 255) and the rest is whatever the flash leaves
// of it; period_jitter spreads it ± per star so neighbors never sync.
uniform float step_seconds : hint_range(0.03, 1.0) = 0.1;
uniform float hold_seconds : hint_range(0.0, 3.0) = 0.0;
uniform float dim_hold_seconds : hint_range(0.0, 3.0) = 0.0;
uniform float period_slow_seconds : hint_range(0.5, 30.0) = 8.0;
uniform float period_fast_seconds : hint_range(0.5, 30.0) = 1.5;
uniform float period_jitter : hint_range(0.0, 0.5) = 0.2;
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


// A console 0 would divide by zero below.
float frame_seconds() {
	return max(step_seconds, 0.01);
}


// x: seconds since this star's latest flash began.
// y: that flash's ordinal; its parity alternates a two-shape star.
// The period never undercuts the longest flash plus one frame of rest, so a
// fast star can't start a new flash before the last one has pulled its tails
// back in and settled.
vec2 flash_clock(ivec2 cell, float cadence, float t) {
	float period = mix(period_slow_seconds, period_fast_seconds, cadence)
			* mix(1.0 - period_jitter, 1.0 + period_jitter, star_hash(cell, 1u));
	float longest_flash = float(2 * MAX_REACH - 1) * frame_seconds()
			+ hold_seconds + 2.0 * dim_hold_seconds;
	period = max(period, longest_flash + frame_seconds());
	float clock = t + star_hash(cell, 2u) * period;
	float index = floor(clock / period);
	return vec2(clock - index * period, index);
}


// Tail length `elapsed` seconds into a flash that peaks at `peak` px: 1, 2, …,
// peak, …, 2, 1, a frame each. The peak frame holds hold_seconds more; the
// 1 px frames either side of it hold dim_hold_seconds more (a 1 px star's one
// frame IS its peak). A 0 peak is one frame of bare core flare. -1 once the
// flash is over.
int flash_reach(float elapsed, int peak) {
	float frame = frame_seconds();
	int side_frames = max(peak - 1, 0);
	float dim_hold = side_frames > 0 ? dim_hold_seconds : 0.0;
	float side_length = float(side_frames) * frame + dim_hold;
	if (elapsed < side_length) {
		// Growing, the held 1 px frame first.
		float grown = elapsed - dim_hold;
		return grown < frame ? 1 : 1 + int(grown / frame);
	}
	elapsed -= side_length;
	if (elapsed < frame + hold_seconds) {
		return peak;
	}
	elapsed -= frame + hold_seconds;
	if (elapsed >= side_length) {
		return -1;
	}
	// Shrinking, the held 1 px frame last.
	return max(side_frames - int(elapsed / frame), 1);
}


// k = distance from the core, reach = the tail's current length.
float tail_alpha(int k, int reach) {
	float depth = float(reach - k) / float(MAX_REACH - 1);
	return mix(tail_tip_alpha, 1.0, depth);
}


// Alpha this star contributes at `offset` (fragment texel − star texel).
float star_alpha(ivec2 cell, vec3 channels, ivec2 offset, float t) {
	vec2 cycle = flash_clock(cell, channels.b, t);
	// One shape plays per flash; a two-shape star takes turns, X first.
	bool has_x = channels.r > STAR_THRESHOLD;
	bool has_plus = channels.g > STAR_THRESHOLD;
	bool odd_flash = mod(cycle.y, 2.0) >= 1.0;
	bool x_plays = has_x && !(has_plus && odd_flash);
	bool plus_plays = has_plus && !x_plays;
	float level = x_plays ? channels.r : (plus_plays ? channels.g : 0.0);
	int peak = int(round(level * float(MAX_REACH) * twinkle_amount));
	int reach = flash_reach(cycle.x, peak);
	ivec2 a = abs(offset);

	if (offset == ivec2(0)) {
		// The core brightens a step with each tail frame, full at the peak. A
		// blue-only star has no tails, so its whole twinkle is this flare.
		float rest = mix(rest_alpha_min, 1.0, max(channels.r, channels.g));
		if (reach < 0) {
			return rest;
		}
		float swell = peak > 0 ? float(reach) / float(peak) : 1.0;
		return mix(rest, 1.0, swell * twinkle_amount);
	}
	int k = 0;
	if (x_plays && a.x == a.y) {
		k = a.x;
	} else if (plus_plays && min(a.x, a.y) == 0) {
		k = max(a.x, a.y);
	}
	return k > 0 && k <= reach ? tail_alpha(k, reach) : 0.0;
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
	// Smooth time on purpose: the frames are already stepped. Don't snap t to
	// a fixed fps — any frame that isn't a whole number of ticks gets re-chopped
	// unevenly (300 ms frames at 12 fps play 250/333).
	float t = TIME * time_scale + time_offset;
	COLOR = vec4(star_color.rgb, star_color.a * sky_alpha(cell, t)) * vertex_modulate;
}
