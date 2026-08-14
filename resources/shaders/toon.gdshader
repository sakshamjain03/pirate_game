shader_type spatial;
// diffuse_toon/specular_toon only affect the built-in lighting model, but
// this shader supplies its own light() function below, which overrides both
// — so only cull_back has any effect here.
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
uniform float metallic  = 0.0;
uniform float roughness = 0.5;

// Toon light ramp. NdotL below `toon_band_1` uses `toon_shade_low`, between the
// two bands uses `toon_shade_mid`, above `toon_band_2` is fully lit. Exposed as
// uniforms so the art direction stays data-driven (AGENTS.md) — raise the shade
// values for a flatter, more graphic look, lower them for more contrast.
uniform float toon_band_1  : hint_range(0.0, 1.0) = 0.25;
uniform float toon_band_2  : hint_range(0.0, 1.0) = 0.62;
uniform float toon_shade_low : hint_range(0.0, 1.0) = 0.42;
uniform float toon_shade_mid : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO    = albedo.rgb * albedo_tex.rgb;
	METALLIC  = metallic;
	ROUGHNESS = roughness;
}

void light() {
	// Godot hands `light()` a LIGHT_COLOR that is already color * energy * PI.
	// The PI is baked in for the built-in Lambert BRDF, which divides it back
	// out; a custom light() that uses LIGHT_COLOR raw is therefore ~3.14x
	// overexposed per light. With the sun at energy 1.3 and the fill at 0.35
	// that put every lit surface around 4-5x, far past the top of the filmic
	// tonemap curve — colors crushed to a desaturated warm white (taking the
	// sun's (1.0, 0.9, 0.72) tint with them, hence the yellow cast) and
	// everything sat above glow_hdr_threshold so the whole frame bloomed.
	// The ocean was unaffected only because water.gdshader has no custom
	// light() and so gets the correct built-in division.
	vec3 light_energy = LIGHT_COLOR / PI;

	// Do NOT multiply these terms by ALBEDO. Godot multiplies DIFFUSE_LIGHT by
	// ALBEDO itself once light() has returned, so doing it here as well shaded
	// every surface with albedo *squared*. Squaring leaves the dominant channel
	// almost untouched while crushing the other two, so it read as a huge
	// saturation/hue shift rather than as a brightness error: sand went from
	// (255,229,202) to (255,175,141), palm fronds from (125,237,196) to
	// (52,206,149). Verified by emitting a constant LIGHT_COLOR from light()
	// and observing the rendered pixels still vary per surface, tracking each
	// surface's own hue. SPECULAR_LIGHT is not albedo-multiplied, so the
	// specular term below is unaffected.
	float NdotL = dot(NORMAL, LIGHT);

	// Banded toon ramp. This was previously smoothstep(0.0, 0.02, NdotL) — a
	// near-binary edge, so every surface facing the light at all snapped to
	// full brightness and every surface facing away snapped to fill. With no
	// values in between, hulls, sails and terrain all rendered as the same
	// flat pale tone regardless of how they were angled, which is what made
	// the game read as chalky and cardboard-like.
	//
	// Three lit bands (shadow / mid / full) keep the hard cel edges the style
	// depends on while restoring the tonal separation that makes form legible:
	// a deck now reads brighter than the hull side beneath it.
	float lit = smoothstep(0.0, 0.02, NdotL);
	float band = NdotL <= 0.0 ? 0.0
		: (NdotL < toon_band_1 ? toon_shade_low
		: (NdotL < toon_band_2 ? toon_shade_mid : 1.0));

	vec3 diffuse = light_energy * band * ATTENUATION;
	float diff = lit;

	// Warm/cool ambient fill for the shadow side. WorldEnvironment ambient
	// light contributes too, but on its own it reads flat across a hard
	// toon shadow edge — this term adds a subtle color-graded fill (cool
	// into shadow, warm near the terminator) so shadowed faces read as
	// shaded rather than going to flat black or losing all definition.
	// Deeper and bluer than before (was 0.15 flat with a paler cool tone). A
	// bright neutral fill lifted every shadow toward the same washed-out value
	// as the lit side, collapsing contrast — the other half of the "chalky"
	// problem. Shadows now sit lower and cooler, so lit faces actually read as
	// lit and the low-poly forms regain their volume.
	vec3 cool_color = vec3(0.34, 0.45, 0.72);
	vec3 warm_color = vec3(0.95, 0.78, 0.58);
	vec3 ambient = mix(cool_color, warm_color, band) * (1.0 - band) * 0.10;

	// Rim light — bright edge glow (sells the cartoon look)
	float rim     = 1.0 - clamp(dot(VIEW, NORMAL), 0.0, 1.0);
	rim           = pow(rim, 3.5);
	vec3 rim_col  = light_energy * rim * 0.15 * diff * ATTENUATION;

	// Hard specular highlight. The cutoff runs *with* roughness, not against
	// it: a rough surface (sailcloth, wood, sand at roughness 0.9) gets a
	// highlight only where the half-vector is nearly dead-on, a smooth one
	// (brass) gets a broad hard patch. The previous cutoff was inverted —
	// `1.0 - ROUGHNESS * 0.45` bottomed out at 0.595 for the roughest
	// materials, i.e. a solid white blowout across everything within ~53
	// degrees of the half-vector, which is what flared the ship's sails.
	vec3 half_vec = normalize(VIEW + LIGHT);
	float NdotH   = max(0.0, dot(NORMAL, half_vec));
	float spec     = step(mix(0.85, 0.995, ROUGHNESS), NdotH);
	vec3 specular  = light_energy * spec * (metallic + 0.1) * ATTENUATION;

	DIFFUSE_LIGHT  += diffuse + ambient + rim_col;
	SPECULAR_LIGHT += specular;
}
