shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.8, 0.3, 0.1, 1.0);
uniform vec4 empty_color : source_color = vec4(0.3, 0.1, 0.05, 1.0);
uniform vec4 border_color : source_color = vec4(0.15, 0.15, 0.15, 1.0);
uniform float fill_percent : hint_range(0.0, 1.0) = 0.6;
uniform float skew_angle : hint_range(0.0, 45.0) = 45.0;
uniform float border_px : hint_range(0.0, 4.0) = 1.0;
uniform float radius_px : hint_range(0.0, 10.0) = 3.0;
uniform vec2 rect_size = vec2(100.0, 14.0);

float rounded_box_sdf(vec2 center_dist, vec2 half_size, float radius) {
	vec2 q = abs(center_dist) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 pos_px = UV * rect_size;
	vec2 center = rect_size * 0.5;

	float dist = rounded_box_sdf(pos_px - center, center, radius_px);

	// Inner color: fill or empty based on diagonal threshold
	float skew = tan(radians(skew_angle)) * rect_size.y / (2.0 * rect_size.x);
	float threshold = fill_percent + skew - (skew * 2.0 * UV.y);
	vec4 inner = UV.x < threshold ? fill_color : empty_color;

	// Blend border -> inner using SDF distance
	float border_blend = smoothstep(0.0, -border_px, dist);
	vec4 shape_color = mix(border_color, inner, border_blend);

	// Anti-aliased outer edge
	float alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
	COLOR = vec4(shape_color.rgb, shape_color.a * alpha);
}
