shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D macro_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.82;
uniform float rock_pixel_depth : hint_range(0.0, 1.0) = 0.185;
uniform float silt_pixel_depth : hint_range(0.0, 1.0) = 0.061;
varying vec3 wp;
varying vec3 wn;

vec2 rotation2(vec2 p, float a) {
	return vec2(p.x*cos(a)-p.y*sin(a),p.x*sin(a)+p.y*cos(a));
}

void vertex() {
	wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec3 macro=texture(macro_map,UV).rgb;
	vec3 n=normalize(wn);
	vec3 weights=pow(abs(n),vec3(5.0));
	weights/=max(dot(weights,vec3(1.0)),0.0001);
	vec2 planar=wp.xz;
	vec3 small=texture(detail_map,rotation2(planar,0.72)/22.0).rgb;
	vec3 longgrain=texture(detail_map,rotation2(planar,-0.43)/48.0+vec2(0.29,0.86)).rgb;
	float silt=mix(small.r,longgrain.r,0.30)-0.48;
	float foliation=texture(detail_map,rotation2(wp.zy,0.19)/35.5+vec2(0.38,0.72)).g*weights.x;
	foliation+=texture(detail_map,rotation2(planar,0.71)/39.2+vec2(0.64,0.12)).g*weights.y;
	foliation+=texture(detail_map,rotation2(wp.xy,-0.28)/36.7+vec2(0.76,0.62)).g*weights.z;
	// Oblique irregular zones break up the repeating fractured limestone cells.
	float field=texture(detail_map,rotation2(wp.xz,0.74)/123.0+vec2(0.27,0.15)).b;
	float broad=texture(detail_map,rotation2(vec2(wp.x+wp.z*0.53,wp.y*1.48),-0.49)/66.8+vec2(0.19,0.47)).g;
	float rock=mix(foliation,broad,0.36+0.23*smoothstep(0.37,0.62,field))-0.47;
	float cortical=smoothstep(0.12,0.42,1.0-n.y);
	float nearfade=1.0-smoothstep(105.0,350.0,length(VERTEX));
	float side=clamp(detail_strength*nearfade,0.0,1.0);
	float tone=mix(silt*0.72,(rock*.97+(field-0.49)*.33),cortical);
	vec3 altered=macro*exp2(tone*2.15*side);
	// The pigment remains dominant. Steeper clefts take a small colder mineral cast.
	altered*=mix(vec3(1.0),vec3(0.865,0.901,0.956),cortical*side);
	ALBEDO=altered;
	ROUGHNESS=clamp(0.93+silt*0.12-rock*cortical*0.14,0.8,1.0);
	SPECULAR=0.23;
	// Screen-space surface gradient, with mip fade: no displaced geometry or collision seam.
	float h=mix(silt*silt_pixel_depth,rock*rock_pixel_depth,cortical)*side;
	vec3 axisU=dFdx(VERTEX);
	vec3 axisV=dFdy(VERTEX);
	vec3 crossU=cross(axisV,NORMAL);
	vec3 crossV=cross(NORMAL,axisU);
	float determinant=dot(axisU,crossU);
	vec3 gradient=sign(determinant)*(dFdx(h)*crossU+dFdy(h)*crossV);
	NORMAL=normalize(max(0.0001,abs(determinant))*NORMAL-gradient);
}
