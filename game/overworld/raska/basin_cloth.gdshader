shader_type spatial;
render_mode cull_disabled;
uniform vec4 dye : source_color = vec4(.4,.3,.2,1.0);
varying vec3 anchored;
void vertex() { anchored=VERTEX; }
void fragment() {
	vec2 strand=vec2(anchored.x+anchored.z,anchored.y+anchored.z*.71);
	float woven=sin(strand.x*63.0)*sin(strand.y*61.0);
	float fade=sin(strand.x*.6+sin(strand.y*.82)*.9)*sin(strand.y*.67);
	float fibers=cos(strand.x*31.0+strand.y*19.0);
	ALBEDO=dye.rgb*(.93+.06*fade+.018*woven+.009*fibers);
	ROUGHNESS=.92;
}
