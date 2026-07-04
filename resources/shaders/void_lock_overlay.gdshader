shader_type canvas_item;

// Drawn on top of a void-locked move/passive chip (paired with move_chip_fill's
// `lock_desaturate`, which greys the chip body underneath). Reproduces the two
// remaining layers of Lawrence's void-lock mockup programmatically:
//   * a ~50% dark scrim  → the mockup's "shadow" layer (opacity 138/255)
//   * twinkling gold motes → the mockup's "void star" layers
// Pixel-snapped so motes land on whole pixels at the game's integer scaling.

uniform vec2 rect_size = vec2(113.0, 14.0);
uniform vec4 shadow_color : source_color = vec4(0.08, 0.08, 0.11, 1.0);
uniform float shadow_alpha : hint_range(0.0, 1.0) = 0.5;
uniform vec4 sparkle_color : source_color = vec4(0.92, 0.80, 0.34, 1.0);
// Fraction of cells that host a mote, and how big each cell is (px).
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.22;
uniform float cell_px = 6.0;
uniform float sparkle_speed = 2.6;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 px = floor(UV * rect_size);          // integer pixel within the chip
	vec3 col = shadow_color.rgb;
	float a = shadow_alpha;

	// One candidate mote per cell, at a fixed sub-cell pixel with its own phase.
	vec2 cell = floor(px / cell_px);
	if (hash21(cell + 3.0) < sparkle_density) {
		vec2 sub = vec2(hash21(cell + 11.0), hash21(cell + 23.0));
		vec2 mote_px = floor(cell * cell_px + sub * (cell_px - 1.0));
		float phase = hash21(cell + 7.0) * 6.2831853;
		float tw = 0.5 + 0.5 * sin(TIME * sparkle_speed + phase);
		tw = smoothstep(0.55, 1.0, tw);        // sharp, mostly-off twinkle
		if (all(equal(mote_px, px))) {
			col = mix(col, sparkle_color.rgb, tw);
			a = mix(a, 1.0, tw);
		}
	}

	COLOR = vec4(col, a);
}
