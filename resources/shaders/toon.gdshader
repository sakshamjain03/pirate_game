shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
uniform float metallic  = 0.0;
uniform float roughness = 0.5;

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO    = albedo.rgb * albedo_tex.rgb;
	METALLIC  = metallic;
	ROUGHNESS = roughness;
}

void light() {
	// Crisp 2-band toon shading — hard shadow boundary
	float NdotL = dot(NORMAL, LIGHT);
	float diff   = smoothstep(0.0, 0.02, NdotL);  // near-binary shadow edge

	// Half-tone warm/cool ambient shift in shadow
	vec3 warm_color = vec3(1.0, 0.95, 0.8);
	vec3 cool_color = vec3(0.5, 0.6, 0.8);
	vec3 diffuse    = LIGHT_COLOR * ALBEDO * diff * ATTENUATION;
	vec3 ambient    = mix(cool_color, warm_color, diff) * ALBEDO * (1.0 - diff) * 0.15;

	// Rim light — bright edge glow (sells the cartoon look)
	float rim     = 1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0);
	rim           = pow(rim, 3.5);
	vec3 rim_col  = LIGHT_COLOR * rim * 0.25 * diff * ATTENUATION;

	// Hard specular highlight
	vec3 half_vec = normalize(VIEW + LIGHT);
	float NdotH   = max(0.0, dot(NORMAL, half_vec));
	float spec     = step(1.0 - ROUGHNESS * 0.45, NdotH);
	vec3 specular  = LIGHT_COLOR * spec * (metallic + 0.1) * ATTENUATION;

	DIFFUSE_LIGHT  += diffuse + ambient + rim_col;
	SPECULAR_LIGHT += specular;
}
