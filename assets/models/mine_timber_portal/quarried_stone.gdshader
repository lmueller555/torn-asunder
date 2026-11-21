shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D baked_surface : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D baked_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 limestone : source_color = vec4(0.535, 0.507, 0.462, 1.0);
uniform vec4 pale_quartz : source_color = vec4(0.608, 0.584, 0.527, 1.0);
uniform vec4 ironstone : source_color = vec4(0.488, 0.433, 0.366, 1.0);
uniform vec4 slate : source_color = vec4(0.447, 0.470, 0.475, 1.0);

varying vec3 local_position;
varying float block_seed;
varying float bevel_contact;

void vertex() {
	local_position = VERTEX;
	block_seed = UV2.y;
	bevel_contact = COLOR.r;
}

void fragment() {
	float lot = floor(block_seed / 100.0);
	float seed = mod(block_seed, 100.0);
	vec2 coords = UV * vec2(0.62, 0.74) + fract(vec2(seed * 0.167, seed * 0.317));
	vec3 surface_sample = texture(baked_surface, coords).rgb;
	vec3 stone = limestone.rgb;
	if (lot == 1.0) {
		stone = pale_quartz.rgb;
	} else if (lot == 2.0) {
		stone = ironstone.rgb;
	} else if (lot == 3.0) {
		stone = slate.rgb;
	}
	float wet_base = 1.0 - smoothstep(0.06, 1.35, local_position.y);
	stone *= 0.77 + surface_sample.r * 0.34;
	stone *= mix(vec3(1.0), vec3(0.75, 0.83, 0.72), wet_base * (0.27 + surface_sample.b * 0.45));
	ALBEDO = mix(stone, pale_quartz.rgb, surface_sample.b * (lot == 1.0 || lot == 3.0 ? 0.10 : 0.035));
	ROUGHNESS = surface_sample.g;
	SPECULAR = 0.24;
	NORMAL_MAP = texture(baked_normal, coords).rgb;
	// Contact is authored at the top/bottom seat and baked as a clean gradient
	// into the mesh; retain physical light and cast shadow on the actual chip.
	AO = mix(0.76, 1.0, bevel_contact);
	NORMAL_MAP_DEPTH = 1.07;
}
