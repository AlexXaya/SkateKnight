shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Toon shading controls (kept consistent with toon.gdshader style).
uniform vec3 shadow_tint : source_color = vec3(0.25, 0.25, 0.3);
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.08;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.18;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

// Brick look.
uniform vec4 brick_color : source_color = vec4(0.22, 0.22, 0.24, 1.0);
uniform vec4 brick_color_alt : source_color = vec4(0.18, 0.18, 0.20, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.09, 0.095, 0.11, 1.0);
uniform float uv_scale : hint_range(0.1, 50.0) = 6.0;
uniform vec2 brick_size = vec2(2.0, 1.0); // width:height ratio in UV grid space
uniform float mortar_thickness : hint_range(0.0, 0.25) = 0.06;
uniform float edge_softness : hint_range(0.0, 0.25) = 0.03;

float hash21(vec2 p) {
	// Cheap deterministic hash for per-brick variation.
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	// Scale UVs and build a brick grid.
	vec2 uv = UV * uv_scale;

	// Brick cell coords.
	vec2 cell = floor(uv / brick_size);
	vec2 local = fract(uv / brick_size);

	// Offset every other row by half a brick (classic running bond).
	float row = cell.y;
	float offset = mod(row, 2.0) * 0.5;
	local.x = fract(local.x + offset);

	// Mortar mask: 1.0 in mortar, 0.0 in brick.
	float mx = smoothstep(mortar_thickness, mortar_thickness + edge_softness, local.x)
		* (1.0 - smoothstep(1.0 - mortar_thickness - edge_softness, 1.0 - mortar_thickness, local.x));
	float my = smoothstep(mortar_thickness, mortar_thickness + edge_softness, local.y)
		* (1.0 - smoothstep(1.0 - mortar_thickness - edge_softness, 1.0 - mortar_thickness, local.y));
	float brick_mask = mx * my;
	float mortar_mask = 1.0 - brick_mask;

	// Per-brick subtle variation.
	float h = hash21(cell);
	vec3 bcol = mix(brick_color.rgb, brick_color_alt.rgb, step(0.5, h));
	bcol *= mix(0.92, 1.06, h);

	ALBEDO = mix(mortar_color.rgb, bcol, brick_mask);
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

