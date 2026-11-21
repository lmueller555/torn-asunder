shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D macro_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.82;
uniform float rock_pixel_depth : hint_range(0.0, 1.0) = 0.185;
uniform float silt_pixel_depth : hint_range(0.0, 1.0) = 0.061;
uniform sampler2D mineral_masks : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 bank_position;
varying vec3 wp;
varying vec3 wn;

vec2 rotation2(vec2 p, float a) {
	return vec2(p.x*cos(a)-p.y*sin(a),p.x*sin(a)+p.y*cos(a));
}

float west_bank(float z) {
	// Sparse piecewise samples of the locked main channel shore, for colour only.
	float Z[22] = float[22](-352.,-329.,-300.,-290.,-280.,-270.,-260.,-250.,-240.,-230.,-220.,
		-210.,-200.,-190.,-180.,-170.,-160.,-150.,-140.,-130.,-120.,-104.);
	float X[22] = float[22](377.1,367.1,360.850922,358.433893,355.837860,352.608087,
		348.436383,343.406036,337.948114,332.564044,327.488580,322.694012,317.815033,
		312.408917,306.371423,300.123700,294.476038,290.156952,287.601599,286.791620,287.464325,291.340000);
	int i = z < -329.0 ? 0 : (z < -300.0 ? 1 : clamp(int(floor((z+300.0)*.10))+2,2,20));
	return mix(X[i],X[i+1],clamp((z-Z[i])/(Z[i+1]-Z[i]),0.,1.));
}

vec3 tri_sample(vec3 at,vec3 w,float inv,vec3 offsets) {
	return texture(mineral_masks,at.zy*inv+vec2(offsets.x,offsets.y)).rgb*w.x
		+texture(mineral_masks,at.xz*inv+vec2(offsets.y,offsets.z)).rgb*w.y
		+texture(mineral_masks,at.xy*inv+vec2(offsets.z,offsets.x)).rgb*w.z;
}

void vertex() {
	bank_position=VERTEX;
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
	float face=0.0;
	if(bank_position.z > -351. && bank_position.z < -99. && bank_position.x>229. && bank_position.x<391. && n.y<.893) {
		float shore=west_bank(bank_position.z)-bank_position.x;
		float region=smoothstep(-351.,-310.,bank_position.z)*(1.-smoothstep(-118.,-99.,bank_position.z))
			*smoothstep(-.4,2.3,shore)*(1.-smoothstep(36.,55.,shore));
		face=region*smoothstep(.107,.55,1.-n.y);
	}
	if(face>0.001) {
		vec3 bank_weights=pow(abs(n),vec3(3.8));
		bank_weights/=max(dot(bank_weights,vec3(1.)),.00001);
		vec3 W = vec3(bank_position.x+.274*bank_position.z,bank_position.y*1.04,bank_position.z-.112*bank_position.x);
		vec3 coarse=tri_sample(W,bank_weights,1./57.,vec3(.40,.19,.63));
		vec3 clast=tri_sample(W,bank_weights,1./19.5,vec3(.06,.84,.37));
		float sineA=sin(.62*bank_position.y-.043*bank_position.x+.059*bank_position.z+3.7*coarse.r);
		float sineB=sin(1.43*bank_position.y+.021*bank_position.x+.10*bank_position.z+4.4*clast.r);
		float stepgrain=smoothstep(-.07,.31,sineA*.68+sineB*.18);
		float lith=clamp(.54+(coarse.r-.5)*.79+(clast.g-.5)*.30+stepgrain*.17,0.,1.);
		vec3 oldalluvium=mix(vec3(.234,.201,.149),vec3(.467,.407,.310),lith);
		vec3 weathered_shale=mix(vec3(.264,.266,.225),vec3(.421,.411,.324),lith);
		float cool=smoothstep(.33,.722,coarse.g+.14*sin(.033*bank_position.z+.029*bank_position.x));
		vec3 bed=mix(oldalluvium,weathered_shale,cool*.69);
		// Gravel along the lowest edge, then oxidized muted streaks; localized rather than a uniform dark ribbon.
		float gravel=smoothstep(.31,.74,clast.b)*(1.-smoothstep(7.,22.,bank_position.y));
		bed+=gravel*vec3(.069,.066,.050);
		bed*=.93+.13*clast.g;
		float details=clamp((.59+.38*coarse.r)*face,0.,1.);
		ALBEDO=mix(ALBEDO,bed,details);
		ROUGHNESS=mix(ROUGHNESS,.985,face);
		SPECULAR=mix(SPECULAR,.25,face);
		// Matte diffuse rebound on the cliff face; no added lights, fog or visible emissive textures.
		vec3 N=normalize(mix(n,vec3(0.,1.,0.),face*.54));
		NORMAL=normalize((VIEW_MATRIX*vec4(N,0.)).xyz);
		EMISSION=bed*face*.13;
	}
}
