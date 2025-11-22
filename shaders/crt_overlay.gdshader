shader_type canvas_item;

// GODOT 4 REQUIRED: Screen texture
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// --- GAME BOY SETTINGS ---
group_uniforms GameBoy_Palette;
// The classic "Light" color (Yellowish Green)
uniform vec4 gb_light : source_color = vec4(0.61, 0.83, 0.06, 1.0);
// The classic "Dark" color (Dark Green/Black)
uniform vec4 gb_dark : source_color = vec4(0.06, 0.43, 0.06, 1.0);
// Toggle to snap colors to 4 distinct shades (True Game Boy style) or keep smooth
uniform bool posterize = false; 

// --- CRT SETTINGS ---
group_uniforms Distortion;
uniform float curvature : hint_range(0.0, 10.0) = 3.0;
uniform float vignette_strength : hint_range(0.0, 5.0) = 3.0; 

group_uniforms Scanlines;
uniform float scanline_count : hint_range(0, 1080) = 144.0; // 144 is Game Boy native height
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.5;

// MATH: Fish Eye
vec2 distort_uv(vec2 uv) {
	vec2 centered_uv = uv * 2.0 - 1.0;
	vec2 offset_uv = centered_uv;
	float r = length(centered_uv); 
	float amount = 1.0 + (curvature * 0.1) * (r * r);
	offset_uv *= amount;
	return (offset_uv + 1.0) / 2.0;
}

void fragment() {
	// 1. Distort UVs
	vec2 distorted_uv = distort_uv(SCREEN_UV);
	
	// 2. Check for Bezel (Outside of tube)
	bool outside_screen = distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0;
	
	if (outside_screen) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// 3. Sample the original color
		vec4 original_color = texture(screen_texture, distorted_uv);
		
		// --- STEP 4: APPLY GAME BOY GREEN ---
		
		// Calculate brightness (Luminance) of the pixel
		float luminance = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));
		
		// Optional: Snap to 4 colors (Posterization) for authentic retro feel
		if (posterize) {
			luminance = floor(luminance * 4.0) / 4.0;
		}
		
		// Map the gray value to our Green Palette
		// 0.0 (Black) becomes gb_dark, 1.0 (White) becomes gb_light
		vec3 gb_color = mix(gb_dark.rgb, gb_light.rgb, luminance);
		
		// ------------------------------------

		// 5. Apply Scanlines
		float scanline_pattern = sin(distorted_uv.y * scanline_count * 3.14159 * 2.0);
		float scanline_mask = (scanline_pattern + 1.0) * 0.5;
		
		// Apply scanlines to the GREEN color, not the original
		vec3 final_color = gb_color * (1.0 - (scanline_opacity * (1.0 - scanline_mask)));
		
		// 6. Vignette
		float vignette = 1.0 - length(distorted_uv * 2.0 - 1.0) * (vignette_strength * 0.1);
		final_color *= clamp(vignette, 0.0, 1.0);
		
		COLOR = vec4(final_color, 1.0);
	}
}

