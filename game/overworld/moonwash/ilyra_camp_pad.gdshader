shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform vec4 earth : source_color = vec4(0.48, 0.40, 0.28, 1.0);
varying vec3 ground_point;

float terrain_noise(vec2 p) {
	vec2 c = floor(p);
	vec2 a = fract(p);
	a *= a * (3.0 - 2.0 * a);
	vec4 h = fract(sin(vec4(dot(c,vec2(28.41,81.57)),dot(c+vec2(1.0,0.0),vec2(28.41,81.57)),dot(c+vec2(0.0,1.0),vec2(28.41,81.57)),dot(c+vec2(1.0),vec2(28.41,81.57)))) * 14912.66);
	return mix(mix(h.x,h.y,a.x),mix(h.z,h.w,a.x),a.y);
}

void vertex() {
	ground_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float gravel = terrain_noise(ground_point.xz * 1.8) * 0.61 + terrain_noise(ground_point.xz * 9.9) * 0.39;
	float tone = mix(0.73, 1.19, gravel);
	ALBEDO = earth.rgb * tone;
	ALPHA = COLOR.a * mix(0.60, 0.89, gravel);
	ROUGHNESS = 0.98;
}
