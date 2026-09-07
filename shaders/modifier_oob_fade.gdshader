shader_type canvas_item;

// Darkens a sprite's own pixels by the same out-of-bounds fade function the
// map vignette uses (shaders/vignette.gdshader). Applied to
// TerrainSpriteRenderer overlay sprites (modifiers + decorations) so terrain
// visuals (and their shadows) that protrude past the map edge darken
// consistently with the floor underneath them — without needing the vignette
// polygon to sit above them in z (impossible: terrain sprites and units
// interleave per-row in z, a flat polygon can't separate them).
// In a canvas_item fragment(), the incoming COLOR is ALREADY
// texture(TEXTURE, UV) * modulate — read it, don't sample the texture again
// (sampling twice squares every channel: midtones darken and a 40% shadow
// turns 16%; that bug shipped for a day on 2026-09-07 and read as "the
// buildings got darker and the shadows got lighter").
uniform vec2 map_min;                 // world-space top-left corner of the map
uniform vec2 map_max;                 // world-space bottom-right corner of the map
uniform float fade_width = 32.0;      // pixels from map edge to full darkening
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = COLOR;  // = texture(TEXTURE, UV) * modulate, per the canvas_item contract
	// Per-axis distance OUTSIDE the map rect (0 if within on that axis).
	vec2 outside = max(max(map_min - world_pos, world_pos - map_max), vec2(0.0));
	float dist = length(outside);
	float a = clamp(dist / fade_width, 0.0, 1.0) * fade_color.a;
	COLOR = vec4(mix(tex.rgb, fade_color.rgb, a), tex.a);
}
