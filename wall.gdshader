// TODO: Perhaps we should generate a texture atlas?
shader_type spatial;
render_mode unshaded;

uniform sampler2D tex : filter_nearest;
uniform sampler2D tex_shaded : filter_nearest;

void fragment() {
	// https://docs.godotengine.org/en/stable/classes/class_boxmesh.html
	vec2 UV_adjusted = UV * vec2(3.0, 2.0);

	// Assuming BoxMesh UV2 padding is set to 12.0
	float face = floor(UV2.x * 6.0);

	// Select texture based on face index
	if (face < 0.5) {
		// Front face (0)
		ALBEDO = texture(tex, UV_adjusted).rgb;
	} else if (face < 1.5) {
		// Back face (1)
		ALBEDO = texture(tex, UV_adjusted).rgb;
	} else if (face < 2.5) {
		// Left face (2)
		ALBEDO = texture(tex_shaded, UV_adjusted).rgb;
	} else if (face < 3.5) {
		// Right face (3)
		ALBEDO = texture(tex_shaded, UV_adjusted).rgb;
	} else if (face < 4.5) {
		// Top face (4)
		ALBEDO = texture(tex, UV_adjusted).rgb;
	} else {
		// Bottom face (5)
		ALBEDO = texture(tex, UV_adjusted).rgb;
	}
}