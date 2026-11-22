shader_type spatial;
render_mode cull_disabled;

// Regional fabric and other materials remain physically located. Color variation
// is based on world position, so its texture stays registered through zoom/LOD.
uniform vec4 base_tint : source_color;
uniform int stock = 0; // sailcloth, timber, stone, bronze
uniform bool regional = false;
varying vec3 w;

float grain(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f *= f * (3.0 - 2.0 * f);
	vec4 offsets = vec4(dot(c, vec2(127.1, 311.7)), dot(c + vec2(1.0,0.0),vec2(127.1, 311.7)),
			dot(c + vec2(0.0,1.0),vec2(127.1, 311.7)), dot(c + vec2(1.0),vec2(127.1, 311.7)));
	vec4 v = fract(sin(offsets) * 43758.545);
	return mix(mix(v.x,v.y,f.x), mix(v.z,v.w,f.x), f.y);
}

void vertex() {
	w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = w.xz + vec2(w.y * 0.62, w.y * 0.36);
	float smear = grain(p * 0.71) * 0.55 + grain(p * 2.45) * 0.30 + grain(p * 7.1) * 0.15;
	float salt = mix(0.74, 1.09, smear);
	ROUGHNESS = 0.85;
	if (stock == 0) {
		float weave = 0.5 + 0.5 * sin((p.x + p.y * 0.08) * 141.0) * sin((p.y - p.x * 0.06) * 119.0);
		weave = mix(weave, 0.5, clamp(length(fwidth(p)) * 45.0, 0.0, 1.0));
		float mildew = smoothstep(0.46, 0.68, grain(p * 1.26) * 0.68 + grain(p * 5.3) * 0.32);
		salt = mix(0.75, 1.08, smear) * mix(1.0,0.78,mildew) * mix(0.91,1.04,weave);
		ROUGHNESS = 0.92;
	} else if (stock == 1) {
		float striations = grain(vec2((p.x + p.y) * 21.0, (p.y - p.x) * 1.8));
		salt = mix(0.52, 1.15, smear * 0.65 + striations * 0.35);
		ROUGHNESS = 0.78;
	} else if (stock == 2) {
		float cracks = smoothstep(0.61,0.76,grain(p * 13.2));
		salt = mix(0.59,1.24,smear) * mix(1.0,0.68,cracks);
		ROUGHNESS = 0.98;
	} else {
		METALLIC = 0.34;
		ROUGHNESS = 0.49;
	}
	ALBEDO = base_tint.rgb * (mix(salt, 0.92, regional ? 0.64 : 0.0));
}
