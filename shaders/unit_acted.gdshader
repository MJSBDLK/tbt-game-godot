// Acted look for a unit's sprite: drain the color, keep the brightness. A
// desaturate keeps dark sprites legible; a darkening multiply sinks them into
// the ground — don't add one back. Known cost: an already-gray unit barely
// changes.
//
// COLOR already holds texture × modulate (canvas_item contract), so the hit
// flash and death fade still ride modulate on top — never sample TEXTURE again.
shader_type canvas_item;

uniform float desaturation : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(luma), desaturation);
}
