// TODO: Perhaps we should generate a texture atlas?
shader_type spatial;
render_mode unshaded;

uniform sampler2D tex_front : filter_nearest;
uniform sampler2D tex_back : filter_nearest;
uniform sampler2D tex_left : filter_nearest;   // shaded
uniform sampler2D tex_right : filter_nearest;  // shaded
uniform sampler2D tex_top : filter_nearest;    // wasteful
uniform sampler2D tex_bottom : filter_nearest; // wasteful

uniform sampler2D tex_shaded : filter_nearest;

void fragment() {
	// https://docs.godotengine.org/en/stable/classes/class_boxmesh.html
	vec2 UV_adjusted = UV * vec2(3.0, 2.0);

	// Assuming BoxMesh UV2 padding is set to 12.0
	float face = floor(UV2.x * 6.0);

	// Select texture based on face index
	if (face < 0.5) {
		// Front face (0)
		ALBEDO = texture(tex_front, UV_adjusted).rgb;
	} else if (face < 1.5) {
		// Back face (1)
		ALBEDO = texture(tex_back, UV_adjusted).rgb;
	} else if (face < 2.5) {
		// Left face (2)
		ALBEDO = texture(tex_left, UV_adjusted).rgb;
	} else if (face < 3.5) {
		// Right face (3)
		ALBEDO = texture(tex_right, UV_adjusted).rgb;
	} else if (face < 4.5) {
		// Top face (4)
		ALBEDO = texture(tex_top, UV_adjusted).rgb;
	} else {
		// Bottom face (5)
		ALBEDO = texture(tex_bottom, UV_adjusted).rgb;
	}
}