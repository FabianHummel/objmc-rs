#ifndef OBJMC_FRAGMENT_GLSL
#define OBJMC_FRAGMENT_GLSL

vec4 objmc_fragment_lighting(vec3 position, vec4 lightingColor) {
    vec3 normal = normalize(cross(dFdx(position), dFdy(position)));
    return minecraft_mix_light(Light0_Direction, Light1_Direction, normal, lightingColor);
}

#endif
