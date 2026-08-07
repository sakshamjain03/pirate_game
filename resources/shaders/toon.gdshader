shader_type spatial;
// diffuse_toon/specular_toon only affect the built-in lighting model, but
// this shader supplies its own light() function below, which overrides both
// — so only cull_back has any effect here.
render_mode cull_back;

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
	// Crisp 2-band toon shading — hard shadow boundary.
	float NdotL = dot(NORMAL, LIGHT);
	float diff   = smoothstep(0.0, 0.02, NdotL);  // near-binary shadow edge

	vec3 diffuse = LIGHT_COLOR * ALBEDO * diff * ATTENUATION;

	// Warm/cool ambient fill for the shadow side. WorldEnvironment ambient
	// light contributes too, but on its own it reads flat across a hard
	// toon shadow edge — this term adds a subtle color-graded fill (cool
	// into shadow, warm near the terminator) so shadowed faces read as
	// shaded rather than going to flat black or losing all definition.
	vec3 cool_color = vec3(0.55, 0.65, 0.85);
	vec3 warm_color = vec3(1.0, 0.85, 0.65);
	vec3 ambient = mix(cool_color, warm_color, diff) * ALBEDO * (1.0 - diff) * 0.15;

	// Rim light — bright edge glow (sells the cartoon look)
	float rim     = 1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0);
	rim           = pow(rim, 3.5);
	vec3 rim_col  = LIGHT_COLOR * rim * 0.15 * diff * ATTENUATION;

	// Hard specular highlight
	vec3 half_vec = normalize(VIEW + LIGHT);
	float NdotH   = max(0.0, dot(NORMAL, half_vec));
	float spec     = step(1.0 - ROUGHNESS * 0.45, NdotH);
	vec3 specular  = LIGHT_COLOR * spec * (metallic + 0.1) * ATTENUATION;

	DIFFUSE_LIGHT  += diffuse + ambient + rim_col;
	SPECULAR_LIGHT += specular;
}
