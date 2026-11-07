#ifndef OBJMC_DECODE_GLSL
#define OBJMC_DECODE_GLSL

const ivec3 OBJMC_MARKER_RGB = ivec3(12, 34, 56);

ivec4 objmc_get_meta(ivec2 topLeft, int offset) {
    return ivec4(texelFetch(Sampler0, topLeft + ivec2(offset, 0), 0) * 255);
}

int objmc_get_vert_component(ivec2 topLeft, int width, int height, int i) {
    ivec4 value = ivec4(texelFetch(Sampler0, topLeft + ivec2(i % width, height + i / width), 0) * 255);
    return (value.r << 16) + (value.g << 8) + value.b;
}

ivec3 objmc_get_vert(ivec2 topLeft, int width, int height, int i) {
    return ivec3(
        objmc_get_vert_component(topLeft, width, height, i * 3),
        objmc_get_vert_component(topLeft, width, height, i * 3 + 1),
        objmc_get_vert_component(topLeft, width, height, i * 3 + 2));
}

float objmc_get_vec3_component(ivec2 topLeft, int width, int height, int i) {
    vec4 value = texelFetch(Sampler0, topLeft + ivec2(i % width, height + i / width), 0);
    return value.r * 256.0 + value.g + value.b / 256.0;
}

vec3 objmc_get_vec3(ivec2 topLeft, int width, int height, int i) {
    return vec3(
        objmc_get_vec3_component(topLeft, width, height, i * 3),
        objmc_get_vec3_component(topLeft, width, height, i * 3 + 1),
        objmc_get_vec3_component(topLeft, width, height, i * 3 + 2)) * (255. / 256.) - vec3(128);
}

float objmc_get_vec2_component(ivec2 topLeft, int width, int height, int i) {
    vec4 value = texelFetch(Sampler0, topLeft + ivec2(i % width, height + i / width), 0);
    return (value.g * 65280.0 + value.b * 255.0) / 65535.0;
}

vec2 objmc_get_vec2(ivec2 topLeft, int width, int height, int i) {
    return vec2(
        objmc_get_vec2_component(topLeft, width, height, i * 2),
        objmc_get_vec2_component(topLeft, width, height, i * 2 + 1));
}

ivec2 objmc_get_ivec2(ivec4 marker) {
    return ivec2((marker.r << 8) + marker.g, (marker.b << 8) + marker.a);
}

#endif
