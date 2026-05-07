shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.9, 0.12, 0.12, 1.0);
uniform vec3 shadow_tint : source_color = vec3(0.35, 0.08, 0.08);
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.08;

// Glow outline (driven by Fresnel/rim).
uniform vec3 glow_color : source_color = vec3(1.0, 0.15, 0.15);
uniform float glow_strength : hint_range(0.0, 20.0) = 6.0;
uniform float glow_width : hint_range(0.25, 8.0) = 2.2;

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float band = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndotl);
	vec3 base = ALBEDO;
	vec3 shaded = base * shadow_tint;
	vec3 toon = mix(shaded, base, band);

	// Fresnel rim used as an emissive outline.
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), glow_width);
	// Note: EMISSION is a fragment() output; writing it in light() is invalid.

	DIFFUSE_LIGHT = toon * LIGHT_COLOR * ATTENUATION;
}

void fragment() {
	ALBEDO = albedo.rgb;
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), glow_width);
	EMISSION = glow_color * (fresnel * glow_strength);
}

