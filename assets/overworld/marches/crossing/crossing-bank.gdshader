shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D macro_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mineral_masks : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_edge : source_color, filter_linear_mipmap, repeat_disable;
uniform bool clamp_macro = false;
varying vec3 p;
varying vec3 wn;

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
	p=VERTEX;
	wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec3 macro=clamp_macro ? texture(macro_edge,UV).rgb : texture(macro_map,UV).rgb;
	ALBEDO=macro;
	METALLIC=0.;
	ROUGHNESS=.94;
	SPECULAR=.5;
	vec3 n=normalize(wn);
	float face=0.0;
	if(p.z > -351. && p.z < -99. && p.x>229. && p.x<391. && n.y<.893) {
		float shore=west_bank(p.z)-p.x;
		float region=smoothstep(-351.,-310.,p.z)*(1.-smoothstep(-118.,-99.,p.z))
			*smoothstep(-.4,2.3,shore)*(1.-smoothstep(36.,55.,shore));
		face=region*smoothstep(.107,.55,1.-n.y);
	}
	if(face>0.001) {
		vec3 weights=pow(abs(n),vec3(3.8));
		weights/=max(dot(weights,vec3(1.)),.00001);
		vec3 W = vec3(p.x+.274*p.z,p.y*1.04,p.z-.112*p.x);
		vec3 coarse=tri_sample(W,weights,1./57.,vec3(.40,.19,.63));
		vec3 clast=tri_sample(W,weights,1./19.5,vec3(.06,.84,.37));
		float sineA=sin(.62*p.y-.043*p.x+.059*p.z+3.7*coarse.r);
		float sineB=sin(1.43*p.y+.021*p.x+.10*p.z+4.4*clast.r);
		float stepgrain=smoothstep(-.07,.31,sineA*.68+sineB*.18);
		float lith=clamp(.54+(coarse.r-.5)*.79+(clast.g-.5)*.30+stepgrain*.17,0.,1.);
		vec3 oldalluvium=mix(vec3(.234,.201,.149),vec3(.467,.407,.310),lith);
		vec3 weathered_shale=mix(vec3(.264,.266,.225),vec3(.421,.411,.324),lith);
		float cool=smoothstep(.33,.722,coarse.g+.14*sin(.033*p.z+.029*p.x));
		vec3 bed=mix(oldalluvium,weathered_shale,cool*.69);
		// Gravel along the lowest edge, then oxidized muted streaks; localized rather than a uniform dark ribbon.
		float gravel=smoothstep(.31,.74,clast.b)*(1.-smoothstep(7.,22.,p.y));
		bed+=gravel*vec3(.069,.066,.050);
		bed*=.93+.13*clast.g;
		float details=clamp((.59+.38*coarse.r)*face,0.,1.);
		ALBEDO=mix(macro,bed,details);
		ROUGHNESS=mix(.94,.985,face);
		SPECULAR=mix(.5,.25,face);
		// Matte diffuse rebound on the cliff face; no added lights, fog or visible emissive textures.
		vec3 N=normalize(mix(n,vec3(0.,1.,0.),face*.54));
		NORMAL=normalize((VIEW_MATRIX*vec4(N,0.)).xyz);
		EMISSION=bed*face*.13;
	}
}
