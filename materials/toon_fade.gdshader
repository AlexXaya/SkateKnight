shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.85, 1.0);
uniform vec3 shadow_tint : source_color = vec3(0.35, 0.35, 0.45);
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.05;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

// Fade obstacles in as they approach the camera.
uniform float fade_begin_m : hint_range(0.0, 500.0) = 45.0;
uniform float fade_end_m : hint_range(0.0, 500.0) = 70.0;

varying vec3 _world_pos;

void vertex() {
	_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo.rgb;

	float dist = distance(CAMERA_POSITION_WORLD, _world_pos);
	float t = smoothstep(fade_begin_m, fade_end_m, dist);
	ALPHA = albedo.a * (1.0 - t);
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float band = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndotl);
	vec3 base = ALBEDO;
	vec3 shaded = base * shadow_tint;
	vec3 toon = mix(shaded, base, band);

	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power) * rim_strength;
	toon += rim;

	DIFFUSE_LIGHT = toon * LIGHT_COLOR * ATTENUATION;
}

