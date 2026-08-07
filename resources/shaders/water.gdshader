shader_type spatial;
render_mode blend_mix, cull_back, specular_disabled, shadows_disabled;

// === Color ===
uniform vec4 water_color : source_color = vec4(0.106, 0.651, 0.784, 1.0);
uniform vec3 water_color_deep    : source_color = vec3(0.027, 0.302, 0.529); // rich cobalt
uniform vec3 foam_color          : source_color = vec3(0.95, 0.98, 1.0);

// === Depth-by-distance (camera-relative, no screen-depth reconstruction) ===
uniform float depth_distance  = 60.0;  // distance over which shallow fades to deep

// === Gerstner Waves ===
uniform float wave_height = 2.0;
uniform float wave_length = 20.0;
uniform float wave_speed = 1.0;
uniform vec2 wind_direction = vec2(1.0, 0.0);

// === Appearance ===
uniform float transparency = 0.6;
uniform float reflectivity = 0.3;

// === Sparkle & Texture Noise ===
uniform float sparkle_intensity = 0.35;
uniform float sparkle_scale     = 60.0;
uniform float sparkle_speed     = 0.08;
uniform sampler2D wave_noise : hint_default_white, repeat_enable;

// === Old Visual Wave Parameters (for foam and normals) ===
uniform float wave_scale = 150.0;
uniform float wave_speed_1 = 0.05;
uniform float wave_speed_2 = 0.03;


varying vec3 world_pos;
varying float v_view_dist;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    vec2 pos2d = world_pos.xz;
    vec2 dir = normalize(wind_direction);

    // Primary wave
    float k = 2.0 * PI / max(0.1, wave_length);
    float c = sqrt(9.8 / k) * wave_speed;
    float f = k * (dot(pos2d, dir) - c * TIME);

    float h = wave_height * sin(f);

    // Secondary wave
    // rotate dir by approx 0.5 radians
    vec2 dir2 = vec2(dir.x * 0.877 - dir.y * 0.48, dir.x * 0.48 + dir.y * 0.877);
    float k2 = k * 1.5;
    float c2 = sqrt(9.8 / k2) * wave_speed;
    float f2 = k2 * (dot(pos2d, dir2) - c2 * TIME);

    h += (wave_height * 0.5) * sin(f2);

    VERTEX.y += h;

	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_view_dist = -view_pos.z;
}

void fragment() {
	// --- Flat face normal for low-poly look ---
	vec3 f_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = f_normal;

	// --- Distance-based color blend (deeper/richer color further from camera) ---
	float depth_blend = clamp(v_view_dist / depth_distance, 0.0, 1.0);
	vec3  final_color = mix(water_color.rgb, water_color_deep, depth_blend);

	// --- Fresnel rim brightening ---
	float fresnel = sqrt(1.0 - clamp(dot(f_normal, VIEW), 0.0, 1.0));
	final_color   = mix(final_color, vec3(0.85, 0.95, 1.0), fresnel * 0.35);

	// --- Wave crest foam ---
	float t1 = TIME * wave_speed_1 * 2.0;
	float t2 = TIME * wave_speed_2 * 2.0;
	vec2 uv1 = (world_pos.xz / wave_scale) + vec2(t1, 0.0);
	vec2 uv2 = (world_pos.xz / wave_scale) + vec2(0.0, t2);
	float n1 = texture(wave_noise, uv1).r;
	float n2 = texture(wave_noise, uv2).r;
	float wave_crest = smoothstep(0.45, 0.85, n1 * n2); // stylized crest lines, softened so they read as patches not a solid whiteout

	// --- Sun sparkle glint ---
	vec2 sparkle_uv = (world_pos.xz / sparkle_scale) + vec2(TIME * sparkle_speed, TIME * sparkle_speed * 0.7);
	float sparkle_n = texture(wave_noise, sparkle_uv).r;
	float sparkle   = pow(sparkle_n, 12.0) * sparkle_intensity * fresnel;
	final_color     = mix(final_color, vec3(1.0, 1.0, 1.0), sparkle);

	// --- Output ---
	ALBEDO    = mix(final_color, foam_color, wave_crest * 0.35);
	ALPHA     = transparency;
	ROUGHNESS = 1.0 - reflectivity;
	METALLIC  = reflectivity * 0.5;
}
