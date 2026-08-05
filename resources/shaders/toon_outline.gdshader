shader_type spatial;
// Classic toon outline: back-face expanded along normals.
// Apply this as a second surface material on models that need an outline.
// Set render_mode to unshaded so it's always full black.
render_mode unshaded, cull_front;

uniform float outline_width : hint_range(0.0, 0.1) = 0.012;
uniform vec4  outline_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

void vertex() {
	// Expand vertices along their normals in view space to create the outline
	vec4 clip_pos    = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * mat3(MODELVIEW_MATRIX) * NORMAL;

	// Normalize in clip space (prevents outline distortion at oblique angles)
	vec2 offset  = normalize(clip_normal.xy) * outline_width * clip_pos.w;
	clip_pos.xy += offset;

	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA  = outline_color.a;
}
