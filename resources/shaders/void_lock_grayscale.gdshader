shader_type canvas_item;

// Greys + dims a Control's rendered pixels so a void-locked chip's icon/label reads
// "dead" like its shader-desaturated body. Works for both a TextureRect (colour is
// in TEXTURE) and a Label (colour is the font_color in COLOR, masked by the glyph
// atlas in TEXTURE) because it desaturates the FINAL colour = TEXTURE * COLOR.

uniform float dim : hint_range(0.0, 1.0) = 0.5;   // brightness after greying

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(luma) * dim, c.a);
}
