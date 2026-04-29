shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.85, 1.0);
uniform vec3 shadow_tint : source_color = vec3(0.35, 0.35, 0.45);
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.05;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float band = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndotl);
	vec3 base = ALBEDO;
	vec3 shaded = base * shadow_tint;
	vec3 toon = mix(shaded, base, band);

	// Simple rim light for anime pop.
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power) * rim_strength;
	toon += rim;

	DIFFUSE_LIGHT = toon * LIGHT_COLOR * ATTENUATION;
}

