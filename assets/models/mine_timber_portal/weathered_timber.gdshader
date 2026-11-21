shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 heartwood : source_color = vec4(0.49, 0.320, 0.194, 1.0);
uniform vec4 silvered : source_color = vec4(0.405, 0.382, 0.334, 1.0);
uniform vec4 pitch : source_color = vec4(0.256, 0.202, 0.139, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(0.1031, 0.11369));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

float field(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), t.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), t.x), t.y);
}

// Height is in local meters; convert surface gradients to the view normal.
vec3 bump(vec3 p, vec3 n, float height) {
	vec3 x = dFdx(p);
	vec3 y = dFdy(p);
	vec3 a = cross(y, n);
	vec3 b = cross(n, x);
	float det = dot(x, a);
	return normalize(max(0.000001, abs(det)) * n - sign(det) * (dFdx(height) * a + dFdy(height) * b));
}

void fragment() {
	float seed = UV2.y * 7.31;
	vec2 p = UV;
	float close = 1.0 - smoothstep(0.004, 0.030, fwidth(UV.x));
	float growth = 0.0;
	float smaller = 0.5;
	float cracks = 0.0;
	float weather = 0.0;
	if (UV2.x > 0.5) {
		vec2 q = (p - vec2(0.12, -0.065)) * vec2(0.93, 0.61);
		float radius = length(q);
		float angle = atan(q.y, q.x);
		// Uneven wet/dry seasons. Local angular deformation and two interrupted
		// fracture sectors keep the cut face from reading as a target.
		float split_a = max(0.0, cos(angle + 0.78 + radius * 3.4));
		float split_b = max(0.0, cos(angle - 2.25 - radius * 1.64));
		float sector = max(pow(split_a, 162.0), pow(split_b, 230.0) * 0.76);
		float fractured = sector * smoothstep(0.06, 0.29, radius);
		float distorted = radius + radius * (0.086 * sin(3.0 * angle + 0.4) + 0.057 * sin(5.0 * angle - 1.4))
			+ 0.010 * field(q * 20.0 + seed);
		float marks[11] = {0.026, 0.041, 0.070, 0.085, 0.123, 0.147, 0.184, 0.231, 0.268, 0.310, 0.377};
		for (int i = 0; i < 11; i++) {
			float width = 0.0019 + 0.0020 * hash21(vec2(float(i), seed));
			float torn = field(q * (43.0 + float(i) * 0.47) + float(i) * 3.1);
			float arc = 1.0 - smoothstep(width, width * 2.5, abs(distorted - marks[i]));
			growth = max(growth, arc * (0.29 + torn * 0.71));
		}
		growth *= (1.0 - fractured) * close;
		smaller = mix(0.5, field(p * 76.0 + seed), close);
		cracks = fractured;
		weather = 0.2 + 0.26 * smoothstep(0.20, 0.45, radius);
	} else {
		vec2 local = vec2(fract(p.x * 1.13 + seed) - 0.52, fract(p.y * 0.41 + seed * 0.23) - 0.50);
		float knot = exp(-dot(local * vec2(11.0, 16.0), local * vec2(11.0, 16.0)));
		float bend = (field(vec2(p.y * 0.71 + seed, p.x * 3.1)) - 0.5) * 0.058;
		float strand = p.x + bend + local.x * knot * 1.46;
		float wedge = field(vec2(strand * 43.0 + seed, p.y * 0.47));
		float thread = field(vec2(strand * 115.0 - seed, p.y * 1.76));
		float broken = field(vec2(strand * 33.0, p.y * 7.0 + seed));
		growth = smoothstep(0.54, 0.92, wedge * 0.53 + thread * 0.47) * close * (0.28 + broken * 0.72);
		smaller = mix(0.50, field(vec2(strand * 135.0 + seed, p.y * 18.6)), close);
		float checks = field(vec2(strand * 33.0, p.y * 1.86 + seed));
		cracks = smoothstep(0.76, 0.98, checks) * close * 0.91 + 0.51 * knot;
		weather = 0.30 * smoothstep(0.31, 0.79, field(p * vec2(2.0, 1.8) + seed));
		if (UV2.y < 0.98) {
			float foot = 1.0 - smoothstep(-2.23, -1.89, p.y + (smaller - 0.5) * 0.18);
			float strap = 1.0 - smoothstep(0.035, 0.13, min(abs(p.y + 1.57), abs(p.y - 1.54)));
			float stain = smoothstep(0.31, 0.65, field(vec2(strand * 9.7, p.y * 1.2 + seed)));
			weather += foot * (0.26 + stain * 0.34) + strap * 0.26;
		}
	}
	vec3 wood = mix(heartwood.rgb, silvered.rgb, min(weather * 1.12, 0.72));
	wood = mix(wood, pitch.rgb, min(cracks * 0.42 + weather * 0.12, 0.51));
	ALBEDO = wood * (0.92 + growth * 0.155 + smaller * 0.099);
	ROUGHNESS = clamp(0.78 + weather * 0.18 + (1.0 - growth) * 0.07, 0.76, 0.97);
	SPECULAR = 0.245;
	NORMAL = bump(VERTEX, NORMAL, growth * 0.00115 + smaller * 0.00063 - cracks * 0.0022);
}
