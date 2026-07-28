vec3 posOffset = vec3(0);

#if 0
void main()
#endif
{
    isObjmcModel = 0;
    vertexNormal = Normal;

    ivec2 uv = ivec2(UV0 * atlasSize);
    ivec4 t[8];

    // find and read marker pixel -> skip if not found
    t[0] = ivec4(texelFetch(Sampler0, uv, 0) * 255);
    ivec2 uvOffset = get_ivec2(t[0]);
    ivec2 topLeft = uv - uvOffset;
    objmcMarker = get_meta(topLeft, 0);

    if (is_objmc_marker()) {
        isObjmcModel = 1;

        // header
        //  2^32   | 2^(16x2) | 2x2^(16x2)   | 2x2^(16x2)
        //  marker | tex size | data heights | data amounts
        for (int i = 1; i < 8; i++) {
            t[i] = get_meta(topLeft, i);
        }

        ivec2 texSize = get_ivec2(t[1]);

        // data heights
        int uvh = (t[2].r << 8) + t[2].g; // UV offsets (for calculating the topleft)
        int vch = (t[2].b << 8) + t[2].a; // vertex indices
        int vph = (t[3].r << 8) + t[3].g; // vertex positions
        int vth = (t[3].b << 8) + t[3].a; // vertex UVs

        // data amounts
        int numPositions = (t[4].r << 8) + t[4].g; // # positions
        int numNormals = (t[4].b << 8) + t[4].a; // # normals
        int numFrames = (t[5].r << 8) + t[5].g; // # frames

        //relative vertex id from unique face UV
        int corner = gl_VertexID % 3;
        int id = ((uvOffset.y - 1) * texSize.x + uvOffset.x) * 3 + corner;

        // animation
        float time = GameTime * 24000;
        ivec3 encoded = ivec3(round(Color * 255.));
        float timeOffset = ((encoded.r << 16) + (encoded.g << 8) + encoded.b) / 699.0506666667;
        int frame = int(time - timeOffset) % numFrames;
        float transition = fract(time);
        ivec3 frameOffset = ivec3(numPositions, 0, numNormals);

        //read data
        int y = 1 + uvh + texSize.y;
        ivec3 index = get_vert(topLeft, texSize.x, y, id);
        index += frame * frameOffset;
        posOffset = get_vec3(topLeft, texSize.x, y + vch, index.x);
        texCoord = get_vec2(topLeft, texSize.x, y + vch + vph, index.y);
        vertexNormal = get_vec3(topLeft, texSize.x, y + vch + vph + vth, index.z);

        if (numFrames > 1) {
            // next frame
            index = (index + frameOffset) % (frameOffset * numFrames);
            vec3 posOffset2 = get_vec3(topLeft, texSize.x, y + vch, index.x);
            vec3 vertexNormal2 = get_vec3(topLeft, texSize.x, y + vch + vph + vth, index.z);
            posOffset = mix(posOffset, posOffset2, transition);
            vertexNormal = mix(vertexNormal, vertexNormal2, transition);
        }

        vec2 onePixel = 1. / atlasSize;
        //final UV (pos set manually)
        texCoord = (vec2(topLeft.x, topLeft.y + 1 + uvh) + texCoord * texSize) / atlasSize
                //make sure that faces with same UV beginning/ending renders
                + vec2(onePixel.x * 0.0001 * corner, onePixel.y * 0.0001 * ((corner + 1) % 4));
    }
}
