shader_type canvas_item;

global uniform float glow_alpha : hint_range(0.0, 1.0) = 0.85;

uniform float health_fill : hint_range(0.0, 1.0) = 1.0;
uniform float damage_fill : hint_range(0.0, 1.0) = 0.0;
uniform vec4 filled_color : source_color = vec4(0.44, 0.65, 0.43, 1.0);
uniform vec4 filled_glow : source_color = vec4(0.18, 0.31, 0.18, 1.0);
uniform vec4 damage_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 damage_glow : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform bool inverted = false;

// Zone: 0 = empty, 1 = damage preview, 2 = filled health.
// Default: fills bottom-to-top (UV.y=1.0 is bottom).
// Inverted: fills top-to-bottom (for the bottom unit's bar).
int get_zone(float uv_y) {
	float y = inverted ? 1.0 - uv_y : uv_y;
	float filled_threshold = 1.0 - health_fill;
	float damage_threshold = max(0.0, 1.0 - health_fill - damage_fill);

	if (y >= filled_threshold) return 2;
	if (y >= damage_threshold) return 1;
	return 0;
}

// Effective alpha: texture alpha masked to zero in the empty zone.
float zone_alpha(sampler2D tex, vec2 uv) {
	float a = texture(tex, uv).a;
	return (get_zone(uv.y) > 0) ? a : 0.0;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE;
	int zone = get_zone(UV.y);
	float pulse = 0.4 + 0.6 * (0.5 + 0.5 * sin(TIME * pulse_speed));

	// Color the pip based on zone (overrides texture color, keeps alpha for shape)
	vec4 pip_color = vec4(0.0);
	if (tex.a > 0.0) {
		if (zone == 2) {
			pip_color = vec4(filled_color.rgb, tex.a);
		} else if (zone == 1) {
			pip_color = vec4(damage_color.rgb * pulse, tex.a);
		}
		// zone 0: pip shape exists but is empty — stays transparent
	}

	// Orthogonal neighbor sampling using zone-masked alpha
	vec2 uv_up = UV + vec2(0.0, -ps.y);
	vec2 uv_down = UV + vec2(0.0, ps.y);
	vec2 uv_left = UV + vec2(-ps.x, 0.0);
	vec2 uv_right = UV + vec2(ps.x, 0.0);

	float ea_up = zone_alpha(TEXTURE, uv_up);
	float ea_down = zone_alpha(TEXTURE, uv_down);
	float ea_left = zone_alpha(TEXTURE, uv_left);
	float ea_right = zone_alpha(TEXTURE, uv_right);

	float neighbor = max(max(ea_up, ea_down), max(ea_left, ea_right));
	float effective_a = (zone > 0) ? tex.a : 0.0;
	float glow = neighbor * (1.0 - effective_a);

	// Determine glow color from the strongest opaque neighbor's zone
	vec4 glow_col = vec4(0.0);
	if (glow > 0.0) {
		float best = 0.0;
		int best_zone = 0;

		if (ea_up > best) { best = ea_up; best_zone = get_zone(uv_up.y); }
		if (ea_down > best) { best = ea_down; best_zone = get_zone(uv_down.y); }
		if (ea_left > best) { best = ea_left; best_zone = get_zone(UV.y); }
		if (ea_right > best) { best = ea_right; best_zone = get_zone(UV.y); }

		if (best_zone == 2) {
			glow_col = filled_glow;
		} else if (best_zone == 1) {
			glow_col = vec4(damage_glow.rgb * pulse, damage_glow.a);
		}
	}

	// Blend glow and pip (same approach as orthogonal_glow.gdshader)
	COLOR = mix(vec4(glow_col.rgb, glow * glow_alpha), pip_color, pip_color.a);
}
