shader_type spatial;
// Classic toon outline: back-face expanded along normals.
// Apply this as a second surface material on models that need an outline.
// Set render_mode to unshaded so it's always full black.
render_mode unshaded, cull_front;

uniform float outline_width : hint_range(0.0, 0.1) = 0.012;
uniform vec4  outline_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

void vertex() {
	// Expand vertices along their normals in view space, then project —
	// projecting the normal itself (rather than the expanded position)
	// blows up non-linearly near silhouette edges and tears the mesh apart.
	vec4 view_pos     = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal  = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	view_pos.xyz     += view_normal * outline_width;

	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA  = outline_color.a;
}
