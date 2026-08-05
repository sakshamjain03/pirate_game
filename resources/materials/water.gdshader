shader_type spatial;
render_mode specular_schlick_ggx, blend_mix, depth_draw_always;

uniform float wave_height = 2.0;
uniform float wave_length = 20.0;
uniform float wave_speed = 1.0;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform vec4 water_color : source_color = vec4(0.1, 0.37, 0.7, 1.0);
uniform float transparency = 0.6;
uniform float reflectivity = 0.3;

void vertex() {
    vec2 pos2d = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    vec2 dir = normalize(wind_direction);
    
    // Primary wave
    float k = 2.0 * PI / max(0.1, wave_length);
    float c = sqrt(9.8 / k) * wave_speed;
    float f = k * (dot(pos2d, dir) - c * TIME);
    
    float height = wave_height * sin(f);
    
    // Secondary wave
    // rotate dir by approx 0.5 radians
    vec2 dir2 = vec2(dir.x * 0.877 - dir.y * 0.48, dir.x * 0.48 + dir.y * 0.877); 
    float k2 = k * 1.5;
    float c2 = sqrt(9.8 / k2) * wave_speed;
    float f2 = k2 * (dot(pos2d, dir2) - c2 * TIME);
    
    height += (wave_height * 0.5) * sin(f2);
    
    VERTEX.y += height;
}

void fragment() {
    // Low poly flat shading effect
    vec3 f_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
    NORMAL = f_normal;
    
    // Vibrant tropical water colors
    vec3 deep_color = vec3(0.0, 0.4, 0.7);
    vec3 shallow_color = vec3(0.2, 0.8, 0.8);
    
    // Add specular highlights for the low poly facets
    float fresnel = sqrt(1.0 - dot(f_normal, VIEW));
    
    // Base color mix based on height (approximate from vertex y if we had it, but simple mix works)
    ALBEDO = mix(deep_color, shallow_color, fresnel * 0.8);
    
    ALPHA = transparency;
    ROUGHNESS = 1.0 - reflectivity;
    METALLIC = reflectivity * 0.5;
}
