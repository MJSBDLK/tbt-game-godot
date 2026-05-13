// Masks reference-resolution-sized chunks of the HD line art to transparent,
// producing a "torn pixel" / "dropped frame" effect — chunks visually
// disappear, revealing the panel surface (or whatever's behind the mirror
// in HDLayer / SubViewport) through the hole.
//
// Applied to the HD mirror's `material` via HDPortraitSlot.projection_material.
// Works in tandem with glass_panel.gdshader (overlay) — that one paints the
// glass surface above the mirror, this one cuts holes in the mirror's image.
//
// Why this can't live in the overlay shader: the overlay sits IN FRONT OF
// the line art in HDLayer's draw order. Setting overlay alpha to 0 in a
// chunk just lets the line art show through unchanged — doesn't hide it.
// To actually remove pixels of the line art, the shader has to be on the
// line art's own node, modifying its output alpha.
shader_type canvas_item;

// Chunk size in REFERENCE pixels. 1.0 = each chunk is one 640×360 pixel
// (= scale_factor actual screen pixels — 3 at 3× upscale). Larger values
// give chunkier cuts. Independent of the line art's atlas region size or
// the mirror's UV mapping, because we quantize on FRAGCOORD (screen pixels)
// rather than UV.
uniform float chunk_size_in_reference : hint_range(0.5, 8.0) = 1.0;

// === Chunk flicker masking ===
// `flicker_strength` is how much each flickering chunk is masked. 1.0
// fully cuts the chunk (full transparent), 0.5 makes it half-transparent.
// `flicker_chance` is the per-chunk per-time-bucket probability of being
// in the flickering set. Keep low (0.01–0.03) — high values flash
// everything constantly.
// `flicker_rate` controls how often the flickering set is re-rolled.
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.0;
// Step is 1e-5 so the slider can resolve down to ~0.00001 (1-in-100000
// per chunk per bucket). Inspector also accepts typed values below the
// slider's step if you need finer.
uniform float flicker_chance : hint_range(0.0, 0.05, 0.00001) = 0.02;
uniform float flicker_rate : hint_range(1.0, 60.0) = 6.0;

const float REFERENCE_WIDTH = 640.0;


// David Hoskins-style hash. The classic fract(sin(...) * BIG) hash has
// non-uniform distribution at large inputs (sin precision degrades, fract
// near zero crossings clusters at the tails) — which makes very-low
// flicker_chance thresholds trigger ~100× too often because the hash
// produces tiny values more frequently than uniform. This version uses
// integer-bit-fiddling-via-floats and stays uniform across the whole
// input range we care about.
float hash_seeded(vec2 p, float seed) {
	vec3 p3 = fract(vec3(p, seed) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	vec4 src = texture(TEXTURE, UV);

	if (flicker_strength > 0.0) {
		// FRAGCOORD-based quantization — independent of UV remapping by
		// AtlasTexture / KEEP_ASPECT_CENTERED. Scale factor (actual screen
		// pixels per reference pixel) is derived from SCREEN_PIXEL_SIZE.
		// Chunks always end up square (chunk_pixel_size is a scalar) and
		// always at reference resolution regardless of the texture's atlas.
		float scale_factor = (1.0 / SCREEN_PIXEL_SIZE.x) / REFERENCE_WIDTH;
		float chunk_pixel_size = max(1.0, chunk_size_in_reference * scale_factor);
		vec2 ref_coord = floor(FRAGCOORD.xy / chunk_pixel_size);
		float t_bucket = floor(TIME * flicker_rate);
		// Each chunk independently rolls hash < flicker_chance per bucket.
		float roll = hash_seeded(ref_coord, t_bucket);
		if (roll < flicker_chance) {
			// Reduce alpha by flicker_strength — 1.0 = fully cut chunk,
			// 0.5 = half-transparent (chunk looks "thin" rather than gone).
			src.a *= 1.0 - flicker_strength;
		}
	}

	COLOR = src;
}
