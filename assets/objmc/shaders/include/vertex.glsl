#ifndef OBJMC_VERTEX_GLSL
#define OBJMC_VERTEX_GLSL

#include <objmc:decode.glsl>

struct ObjmcVertexData {
    bool isModel;
    ivec4 marker;
    vec3 offset;
    vec3 normal;
    vec2 atlasUv;
};

ObjmcVertexData objmc_vertex() {
    ObjmcVertexData result = ObjmcVertexData(false, ivec4(0), vec3(0.0), Normal, UV0);
    ivec2 uv = ivec2(UV0 * atlasSize);
    ivec4 header[8];

    header[0] = ivec4(texelFetch(Sampler0, uv, 0) * 255);
    ivec2 uvOffset = objmc_get_ivec2(header[0]);
    ivec2 topLeft = uv - uvOffset;
    result.marker = objmc_get_meta(topLeft, 0);

    if (result.marker.rgb != OBJMC_MARKER_RGB) {
        return result;
    }

    result.isModel = true;

    for (int i = 1; i < 8; i++) {
        header[i] = objmc_get_meta(topLeft, i);
    }

    ivec2 modelTextureSize = objmc_get_ivec2(header[1]);

    int uvHeight = (header[2].r << 8) + header[2].g;
    int vertexCountHeight = (header[2].b << 8) + header[2].a;
    int positionHeight = (header[3].r << 8) + header[3].g;
    int uvDataHeight = (header[3].b << 8) + header[3].a;

    int numPositions = (header[4].r << 8) + header[4].g;
    int numNormals = (header[4].b << 8) + header[4].a;
    int numFrames = (header[5].r << 8) + header[5].g;

    int corner = gl_VertexIndex % 3;
    int id = ((uvOffset.y - 1) * modelTextureSize.x + uvOffset.x) * 3 + corner;

    float time = GameTime * 24000;
    ivec3 encoded = ivec3(round(Color * 255.));
    float timeOffset = ((encoded.r << 16) + (encoded.g << 8) + encoded.b) / 699.0506666667;
    int frame = int(time - timeOffset) % numFrames;
    float transition = fract(time);
    ivec3 frameOffset = ivec3(numPositions, 0, numNormals);

    int dataY = 1 + uvHeight + modelTextureSize.y;
    ivec3 index = objmc_get_vert(topLeft, modelTextureSize.x, dataY, id);
    index += frame * frameOffset;
    result.offset = objmc_get_vec3(topLeft, modelTextureSize.x, dataY + vertexCountHeight, index.x);
    result.atlasUv = objmc_get_vec2(topLeft, modelTextureSize.x, dataY + vertexCountHeight + positionHeight, index.y);
    result.normal = objmc_get_vec3(topLeft, modelTextureSize.x, dataY + vertexCountHeight + positionHeight + uvDataHeight, index.z);

    if (numFrames > 1) {
        index = (index + frameOffset) % (frameOffset * numFrames);
        vec3 nextOffset = objmc_get_vec3(topLeft, modelTextureSize.x, dataY + vertexCountHeight, index.x);
        vec3 nextNormal = objmc_get_vec3(topLeft, modelTextureSize.x, dataY + vertexCountHeight + positionHeight + uvDataHeight, index.z);
        result.offset = mix(result.offset, nextOffset, transition);
        result.normal = mix(result.normal, nextNormal, transition);
    }

    vec2 onePixel = 1. / atlasSize;
    result.atlasUv = (vec2(topLeft.x, topLeft.y + 1 + uvHeight) + result.atlasUv * modelTextureSize) / atlasSize
            + vec2(onePixel.x * 0.0001 * corner, onePixel.y * 0.0001 * ((corner + 1) % 4));

    return result;
}

#endif
