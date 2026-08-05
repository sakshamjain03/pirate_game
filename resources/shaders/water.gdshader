shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_toon, specular_toon;

// === Color ===
uniform vec4 water_color : source_color = vec4(0.106, 0.651, 0.784, 1.0);
uniform vec3 water_color_deep    : source_color = vec3(0.027, 0.302, 0.529); // rich cobalt
uniform vec3 foam_color          : source_color = vec3(0.95, 0.98, 1.0);

// === Depth & Foam ===
uniform float foam_thickness  = 2.5;   // wide foam band at island edges
uniform float depth_distance  = 8.0;   // shallow gradient kicks in quickly

// === Depth Texture (for foam intersection) ===
uniform sampler2D depth_texture   : hint_depth_texture,  filter_linear_mipmap;

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
varying float v_wave_height;

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
	v_wave_height = h;
}

void fragment() {
	// --- Flat face normal for low-poly look ---
	vec3 f_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = f_normal;

	// --- Depth-based color blend ---
	float raw_depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc        = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4 view_pos   = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz   /= view_pos.w;
	float scene_depth = -view_pos.z;

	// Surface depth
	vec3 surf_ndc   = vec3(SCREEN_UV * 2.0 - 1.0, FRAGCOORD.z);
	vec4 surf_view  = INV_PROJECTION_MATRIX * vec4(surf_ndc, 1.0);
	surf_view.xyz  /= surf_view.w;
	float surf_depth = -surf_view.z;

	float depth_diff  = scene_depth - surf_depth;
	float depth_blend = clamp(depth_diff / depth_distance, 0.0, 1.0);
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
	float wave_crest = smoothstep(0.42, 0.58, n1 * n2); // sharp stylized crest lines

	// --- Shore foam ---
	float shore_foam = 1.0 - clamp(depth_diff / foam_thickness, 0.0, 1.0);
	float total_foam = max(shore_foam, wave_crest * 0.6);

	// --- Sun sparkle glint ---
	vec2 sparkle_uv = (world_pos.xz / sparkle_scale) + vec2(TIME * sparkle_speed, TIME * sparkle_speed * 0.7);
	float sparkle_n = texture(wave_noise, sparkle_uv).r;
	float sparkle   = pow(sparkle_n, 8.0) * sparkle_intensity * fresnel;
	final_color     = mix(final_color, vec3(1.0, 1.0, 1.0), sparkle);

	// --- Output ---
	ALBEDO    = mix(final_color, foam_color, total_foam);
	ALPHA     = transparency;
	ROUGHNESS = 1.0 - reflectivity;
	METALLIC  = reflectivity * 0.5;
	// Slight specular boost for sun glint highlight
	SPECULAR  = 0.6;
}
