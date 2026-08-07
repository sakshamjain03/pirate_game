shader_type spatial;
// Classic toon outline: back-face expanded along normals.
// Apply this as a second surface material on models that need an outline.
// Set render_mode to unshaded so it's always full black.
render_mode unshaded, cull_front;

// Angular width, not a world-space distance — this is how many world units
// the outline expands per unit of view depth, so the projected screen width
// stays ~constant instead of shrinking to sub-pixel at gameplay range or
// swallowing thin geometry up close (0.006 ~= 4px tall at fov 75, 1080p).
uniform float outline_width : hint_range(0.0, 0.05) = 0.006;
uniform vec4  outline_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

void vertex() {
	// Expand vertices along their normals in view space, then project —
	// projecting the normal itself (rather than the expanded position)
	// blows up non-linearly near silhouette edges and tears the mesh apart.
	vec4 view_pos     = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal  = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);

	// Scale the expansion by view depth (-view_pos.z is distance in front of
	// the camera) so it covers the same angular size at any range. Without
	// this a fixed metric offset is huge close up and imperceptible at
	// normal play distance — the previous fixed 0.012m read as ~11px up
	// close but ~0.2px at a typical 45m, and on thin geometry (rigging,
	// ropes) it could exceed the mesh's own thickness and swallow it whole.
	float dist_scale = -view_pos.z;
	view_pos.xyz     += view_normal * outline_width * dist_scale;

	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA  = outline_color.a;
}
