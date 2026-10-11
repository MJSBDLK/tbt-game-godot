shader_type canvas_item;

// Painted smoke, alive. The painting is the smoke at rest: pixels on one
// checker grid, shaded however the painter lit them. A thickness field drifts
// through it a frame at a time: where it runs thin, painted pixels drop out;
// where it runs thick, the holes between them (the other checker grid) fill
// in, thick_steps ramp steps lighter than the pixels around. Every pixel the
// painter placed keeps its colour, and nothing moves off the pixel grid.
// SmokePlume pushes the ArtVariables SMOKE_* knobs into these uniforms.

// The node's own texture again, as a uniform: built-ins can't be read inside
// a function (same as star_twinkle). SmokePlume sets it.
uniform sampler2D smoke_map : filter_nearest, repeat_disable;
uniform float step_seconds : hint_range(0.03, 1.0) = 0.125;
// Sprite px per second the thickness travels: up, and sideways (+ = right).
uniform float rise_speed : hint_range(0.0, 60.0) = 6.0;
uniform float drift_speed : hint_range(-60.0, 60.0) = 3.0;
// Sprite px across one thick or thin patch.
uniform float patch_size : hint_range(1.0, 32.0) = 4.0;
// Roughly the share of painted pixels missing at any moment, and of the holes
// filled thick.
uniform float breakup : hint_range(0.0, 1.0) = 0.3;
uniform float thickness : hint_range(0.0, 1.0) = 0.3;
// The Gray ramp's steps are 0.1 apart, so one step is +0.1 on every channel.
uniform float thick_steps : hint_range(-3.0, 3.0) = 1.0;
// 0 shows the painting as painted (the ui_motion_enabled hook).
uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;
// time = TIME * time_scale + time_offset. Scale 0 freezes a frame for probes.
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;
uniform float time_offset = 0.0;

varying vec4 vertex_modulate;


void vertex() {
	vertex_modulate = COLOR;
}


float cell_hash(ivec2 cell) {
	uint h = uint(cell.x + 4096) * 374761393u + uint(cell.y + 4096) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h & 0x00FFFFFFu) / 16777215.0;
}


float value_noise(vec2 p) {
	ivec2 corner = ivec2(floor(p));
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float bottom = mix(cell_hash(corner), cell_hash(corner + ivec2(1, 0)), f.x);
	float top = mix(cell_hash(corner + ivec2(0, 1)), cell_hash(corner + ivec2(1, 1)), f.x);
	return mix(bottom, top, f.y);
}


// 0 = as thin as it gets, 1 = as thick. Two layers moving at different speeds
// so the pattern changes as it travels instead of sliding past like a belt.
// Stretched about 0.5 because blended noise rarely reaches either end.
float thickness_at(ivec2 cell, float t) {
	vec2 travel = vec2(drift_speed, -rise_speed) * t;
	float size = max(patch_size, 1.0);
	float broad = value_noise((vec2(cell) - travel) / size);
	float fine = value_noise((vec2(cell) - travel * 1.7 + vec2(37.0, 11.0)) / (size * 0.5));
	return clamp(0.5 + (0.65 * broad + 0.35 * fine - 0.5) * 2.0, 0.0, 1.0);
}


vec4 painted(ivec2 cell) {
	ivec2 size = textureSize(smoke_map, 0);
	if (cell.x < 0 || cell.y < 0 || cell.x >= size.x || cell.y >= size.y) {
		return vec4(0.0);
	}
	return texelFetch(smoke_map, cell, 0);
}


vec4 smoke_at(ivec2 cell, float t) {
	vec4 here = painted(cell);
	if (motion_amount <= 0.0) {
		return here;
	}
	float density = thickness_at(cell, t);
	if (here.a > 0.0) {
		return density >= breakup ? here : vec4(0.0);
	}
	// A hole: inside the plume when three or four of its neighbours are painted.
	vec4 around = vec4(0.0);
	float count = 0.0;
	for (int side = 0; side < 4; side++) {
		ivec2 offset = side == 0 ? ivec2(1, 0) : side == 1 ? ivec2(-1, 0) : side == 2 ? ivec2(0, 1) : ivec2(0, -1);
		vec4 neighbour = painted(cell + offset);
		if (neighbour.a > 0.0) {
			around += neighbour;
			count += 1.0;
		}
	}
	if (count < 3.0 || density < 1.0 - thickness) {
		return vec4(0.0);
	}
	around /= count;
	vec3 lit = round(clamp(around.rgb + 0.1 * thick_steps, 0.0, 1.0) * 10.0) / 10.0;
	return vec4(lit, around.a);
}


void fragment() {
	ivec2 cell = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	float frame = max(step_seconds, 0.01);
	float t = floor((TIME * time_scale + time_offset) / frame) * frame;
	COLOR = smoke_at(cell, t) * vertex_modulate;
}
