shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.5, 0.4, 0.28, 1.0);
varying vec3 world;
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
}
void fragment() {
    float grain_edge = grain(world*1.13);
    float shoulder = smoothstep(0.60, 0.98, abs(UV.y)+(grain_edge-0.5)*0.28);
    float approach = smoothstep(0.03, 0.27, UV.x)*(1.0-smoothstep(0.82, 1.0, UV.x));
    ALPHA = min(0.84,(1.0-shoulder)*approach*(0.42+grain_edge*0.48));
    ALBEDO = tint.rgb * mix(0.75,1.19,grain(world*3.4));
    ROUGHNESS = 0.92;
}
