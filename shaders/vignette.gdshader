shader_type canvas_item;

// Out-of-bounds fade that paints the territory outside the map rect. Alpha ramps
// from 0 at the map edge to 1 `fade_width` pixels outside it, then stays solid.
// Applied to a world-space Polygon2D covering a large area around the map.
uniform vec2 map_min;                 // world-space top-left corner of the map
uniform vec2 map_max;                 // world-space bottom-right corner of the map
uniform float fade_width = 32.0;      // pixels from map edge to full opacity
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Per-axis distance OUTSIDE the map rect (0 if within on that axis).
	vec2 outside = max(max(map_min - world_pos, world_pos - map_max), vec2(0.0));
	float dist = length(outside);  // Euclidean distance from nearest map edge/corner
	float a = clamp(dist / fade_width, 0.0, 1.0);
	COLOR = vec4(fade_color.rgb, fade_color.a * a);
}
