shader_type canvas_item;

// Drawn on top of a void-locked move/passive chip (paired with move_chip_fill's
// `lock_desaturate`, which greys the chip body underneath). Just the shadow layer
// of Lawrence's mockup — a ~50% dark scrim (opacity 138/255). The gold particles
// now come from the hosted VoidLockEffect (smoke/bubbles/stars), so the old
// placeholder motes were removed to avoid a doubled sparkle.

uniform vec4 shadow_color : source_color = vec4(0.08, 0.08, 0.11, 1.0);
uniform float shadow_alpha : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	COLOR = vec4(shadow_color.rgb, shadow_alpha);
}
