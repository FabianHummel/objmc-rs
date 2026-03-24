#ifdef VSH

flat out int isObjmcModel;
flat out ivec4 objmcMarker;

bool isObjmcMarker() {
    return objmcMarker.rgb == ivec3(12, 34, 56);
}

ivec4 getmeta(ivec2 topleft, int offset) {
    return ivec4(texelFetch(Sampler0, topleft + ivec2(offset, 0), 0) * 255);
}

float get_pos_component(ivec2 topleft, int w, int h, int i) {
    vec4 v = texelFetch(Sampler0, topleft + ivec2(i % w, h + i / w), 0);
    return v.r * 256 + v.g + v.b / 256,
}

vec3 get_pos(ivec2 topleft, int w, int h, int i) {
    return vec3(
        get_pos_component(topleft, w, h, index * 3),
        get_pos_component(topleft, w, h, index * 3 + 1),
        get_pos_component(topleft, w, h, index * 3 + 2)) * (255. / 256.) - vec3(128);
}

float get_uv_component(ivec2 topleft, int w, int h, int i) {
    vec4 v = texelFetch(Sampler0, topleft + ivec2(i % w, h + i / w), 0);
    return (v.g * 65280 + v.b * 255) / 65535;
}

vec2 get_uv(ivec2 topleft, int w, int h, int i) {
    return vec2(
        get_uv_component(topleft, w, h, i * 2),
        get_uv_component(topleft, w, h, i * 2 + 1));
}

int get_vert_component(ivec2 topleft, int w, int h, int i) {
    ivec4 v = ivec4(texelFetch(Sampler0, topleft + ivec2(i % w, h + i / w), 0) * 255);
    return v.r * 65536 + v.g * 256 + v.b;
}

ivec2 get_vert(ivec2 topleft, int w, int h, int i) {
    return ivec2(
        get_vert_component(topleft, w, h, i * 2),
        get_vert_component(topleft, w, h, i * 2 + 1));
}

#endif

#ifdef FSH

flat in int isObjmcModel;
flat in ivec4 objmcMarker;

#endif
