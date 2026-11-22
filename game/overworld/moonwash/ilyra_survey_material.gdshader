shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.5, 0.4, 0.28, 1.0);
uniform int stock = 0; // 0 wood, 1 stone, 2 iron/bronze, 3 reeds.
uniform bool regional = false;
varying vec3 world;
varying vec3 local_position;
float hash31(vec3 p) {
    return fract(sin(dot(p, vec3(46.37, 10.49, 22.17))) * 43758.5453);
}
float grain(vec3 p) {
    vec3 base = floor(p);
    vec3 part = smoothstep(vec3(0.0), vec3(1.0), fract(p));
    return mix(mix(mix(hash31(base),hash31(base+vec3(1,0,0)),part.x),
        mix(hash31(base+vec3(0,1,0)),hash31(base+vec3(1,1,0)),part.x),part.y),
        mix(mix(hash31(base+vec3(0,0,1)),hash31(base+vec3(1,0,1)),part.x),
        mix(hash31(base+vec3(0,1,1)),hash31(base+vec3(1,1,1)),part.x),part.y),part.z);
}
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    local_position = VERTEX;
}
void fragment() {
    vec3 p = local_position;
    float shade = grain(world*1.7);
    if (!regional && stock == 0) {
        float streaks=grain(world*vec3(7.0,0.45,4.1));
        shade=shade*0.42+streaks*0.58;
    } else if (!regional && stock == 1) {
        float strata=sin(p.y*27.0+grain(p*3.2)*2.5)*0.085;
        shade=shade*0.5+grain(world*11.0)*0.50+strata;
    }
    ALBEDO = tint.rgb * mix(0.79,1.16,shade);
    ROUGHNESS = stock == 2 ? 0.58 : 0.88;
    METALLIC = stock == 2 ? 0.32 : 0.0;
}
