shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Procedural wood + red glow rim.
uniform vec3 shadow_tint : source_color = vec3(0.28, 0.22, 0.16);
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.08;

uniform vec4 wood_light : source_color = vec4(0.45, 0.30, 0.18, 1.0);
uniform vec4 wood_dark : source_color = vec4(0.28, 0.18, 0.10, 1.0);
uniform float wood_scale : hint_range(0.1, 50.0) = 6.0;
uniform float grain_strength : hint_range(0.0, 2.0) = 0.7;

uniform vec3 glow_color : source_color = vec3(1.0, 0.12, 0.12);
uniform float glow_strength : hint_range(0.0, 20.0) = 7.5;
uniform float glow_width : hint_range(0.25, 8.0) = 2.2;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	// Wood rings along U, grain along V (works well on CylinderMesh UVs).
	vec2 uv = UV * wood_scale;
	float h = hash21(floor(uv));
	float rings = sin((uv.x + h) * 6.28318) * 0.5 + 0.5;
	float grain = sin((uv.y * 10.0) + rings * 3.0) * 0.5 + 0.5;
	float t = clamp(mix(rings, grain, 0.35) * grain_strength + (1.0 - grain_strength) * 0.5, 0.0, 1.0);
	vec3 wood = mix(wood_dark.rgb, wood_light.rgb, t);

	ALBEDO = wood;

	// Emissive red rim (outline-like).
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), glow_width);
	EMISSION = glow_color * (fresnel * glow_strength);
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float band = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndotl);
	vec3 base = ALBEDO;
	vec3 shaded = base * shadow_tint;
	vec3 toon = mix(shaded, base, band);
	DIFFUSE_LIGHT = toon * LIGHT_COLOR * ATTENUATION;
}

