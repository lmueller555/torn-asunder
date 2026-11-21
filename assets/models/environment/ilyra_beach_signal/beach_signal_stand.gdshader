shader_type spatial;
render_mode cull_disabled;

varying vec3 fixture;
varying vec3 authored_normal;
void vertex() {
	fixture = VERTEX;
	authored_normal = NORMAL;
}

float bands(float x, float stretch) {
	float wave = x * stretch;
	float visibility = 1.0 - smoothstep(0.2, 0.65, fwidth(wave));
	return sin(wave) * visibility;
}

void fragment() {
	vec3 tint = COLOR.rgb;
	float rough = 0.89;
	float kind = UV.x;
	if (kind < 1.5) {
		// Long, varied grain flows with the mast and across the separate spar.
		float cross_wood = fixture.x+fixture.z*.69;
		float long_wood = fixture.y;
		if (fixture.x > .285) {
			cross_wood = fixture.y+fixture.z*.7;
			long_wood = fixture.x;
		}
		float flow = cross_wood + .004 * sin(long_wood*5.3) + .012*sin(long_wood*1.7);
		float grain = bands(flow,116.0)*.105 + bands(flow+.008*sin(long_wood*8.6),358.0)*.045;
		float broad = sin(flow*34.0)*.075 + sin(flow*61.0)*.05;
		tint *= 1.0 + grain + broad;
		rough = .81;
	} else if (kind < 2.5) {
		float course = smoothstep(-1.59,-1.26,fixture.y);
		float chisel = bands(fixture.x*.63+fixture.z*.49-fixture.y*.4,150.0);
		float age = sin(fixture.x*12.0-fixture.z*9.0+fixture.y*4.0);
		tint *= .86 + course*.13 + chisel*.052 + age*.075;
	} else if (kind < 3.5) {
		rough = .66;
		METALLIC = .34;
		tint *= .94 + .08*sin(fixture.x*19.0+fixture.y*9.0);
	} else if (kind < 4.5) {
		tint *= .93 + .12*bands(fixture.y+fixture.x*.4,160.0);
	} else {
		float weft = bands(fixture.y,370.0);
		float warp = bands(fixture.x,370.0);
		tint *= 1.0 + .065*weft + .075*warp;
	}
	ALBEDO = tint;
	ROUGHNESS = rough;
	SPECULAR = .24;
}
