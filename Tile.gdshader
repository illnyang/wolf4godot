shader_type spatial;
render_mode cull_back, unshaded;

uniform sampler2DArray texture_array : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;

const vec2 texCoords[4] = vec2[4](
    vec2(0.0f, 0.0f),
    vec2(1.0f, 0.0f),
    vec2(1.0f, 1.0f),
    vec2(0.0f, 1.0f)
);

varying vec2 UV_;

void vertex() {
	UV_ = texCoords[int(UV.x)];
}

void fragment() {
	float layer = UV.y;
	vec4 albedo_tex = texture(texture_array, vec3(UV_, layer));
	ALBEDO = albedo_tex.rgb;
}