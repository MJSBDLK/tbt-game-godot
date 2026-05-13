// Glass-surface effect for HUD panels — applied via a CanvasItem `material`
// on a Panel / PanelContainer / ColorRect that has a StyleBoxFlat or fill.
// The shader processes every pixel the host draws (StyleBoxFlat bg + border)
// and layers four passes on top:
//   1. Azure tint — mixes the host's base color toward `glass_tint`.
//   2. Top-down gradient — brighter near the top of the rect, simulating an
//      overhead light source on the glass surface.
//   3. Top-edge highlight — a sharper bright band along the upper edge to
//      sell "polished glass" rather than "flat panel."
//   4. Horizontal scanlines — subtle, gated by `scanline_strength` so they
//      can be killed entirely if they read as noisy.
//
// All parameters are exported as uniforms so the host can be tuned in the
// inspector without touching shader code. Defaults aim for "subtle blue
// glass with a soft top highlight" — increase strengths for more flair.
shader_type canvas_item;

uniform vec4 glass_tint : source_color = vec4(0.298, 0.549, 0.733, 0.4);     // Azure 5 @ 40% mix
uniform vec4 highlight_color : source_color = vec4(0.859, 0.953, 1.0, 1.0);  // Azure 9
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.3;
uniform float top_highlight_strength : hint_range(0.0, 1.0) = 0.25;
uniform float top_highlight_falloff : hint_range(1.0, 16.0) = 4.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.1;
uniform float scanline_density : hint_range(10.0, 300.0) = 60.0;
// Scanline scroll velocity in UV-space units per second. Positive = downward
// marquee, negative = upward. 0.05 = a full panel traversal every 20 seconds
// (slow ambient drift); 0.5 = once every 2 seconds (assertive). 0 = static.
uniform float scanline_speed : hint_range(-2.0, 2.0) = 0.0;


void fragment() {
	vec4 base = COLOR;

	// Skip fully-transparent pixels — outside the StyleBoxFlat's drawn region.
	// Without this guard the effect would expand the panel's apparent rect.
	if (base.a < 0.01) {
		COLOR = base;
	} else {
		// 1. Tint toward glass color
		vec3 tinted = mix(base.rgb, glass_tint.rgb, glass_tint.a);

		// 2. Top-down gradient — top a bit brighter, bottom a bit dimmer.
		float gradient = mix(1.0 + gradient_strength, 1.0 - gradient_strength * 0.5, UV.y);
		tinted *= gradient;

		// 3. Top-edge highlight — quick falloff from the top edge.
		float highlight = pow(max(0.0, 1.0 - UV.y * top_highlight_falloff), 2.0) * top_highlight_strength;
		tinted = mix(tinted, highlight_color.rgb, highlight);

		// 4. Scanlines — sin-wave horizontal darkening, mixed in by strength.
		// Subtracting (TIME * speed) from UV.y shifts the pattern downward as
		// time advances (positive speed → features that were at y_0 at t=0 are
		// at y_0 + speed*dt at t=dt). Negative speed scrolls upward.
		if (scanline_strength > 0.0) {
			float scan = sin((UV.y - TIME * scanline_speed) * scanline_density);
			float scan_factor = mix(1.0, 0.5 + scan * 0.5, scanline_strength);
			tinted *= scan_factor;
		}

		COLOR = vec4(tinted, base.a);
	}
}
