vec3 posOffset = vec3(0);
vec3 vertexNormal = Normal;
ivec2 topLeft;

#if 0
void main()
#endif
{
    isObjmcModel = 0;
    ivec2 uv = ivec2((UV0 * atlasSize));
    ivec4 t[8];
    // marker
    t[0] = ivec4(texelFetch(Sampler0, uv, 0) * 255);
    ivec2 uvOffset = ivec2(t[0].r * 256 + t[0].g, t[0].b * 256 + t[0].a);
    topLeft = uv - uvOffset;
    objmcMarker = ivec4(texelFetch(Sampler0, topLeft, 0) * 255);

    if (is_objmc_marker()) {
        isObjmcModel = 1;

        // header
        //| 2^32   | 2^(16x2) | 2^32      | 2x2^(16x2)   |
        //| marker | tex size | nvertices | data heights |
        for (int i = 1; i <= 4; i++) {
            t[i] = get_meta(topLeft, i);
        }

        ivec2 texture_size = ivec2(t[1].r << 8 + t[1].g, t[1].b << 8 + t[1].a);
        int num_vertices = t[2].r << 24 + t[2].g << 16 + t[2].b << 8 + t[2].a;

        // data heights
        int vp_height = t[3].r << 8 + t[3].g;
        int vt_height = t[3].b << 8 + t[3].a;
        int vn_height = t[4].r << 8 + t[4].g;
        int uv_height = t[4].b << 8 + t[4].a;

        //relative vertex id from unique face uv
        int corner = gl_VertexID % 4;
        int id = ((uvOffset.y - 1) * texture_size.x + uvOffset.x) * 4 + corner;

        //read data
        int y = 1 + uv_height + texture_size.y;
        ivec3 index = get_vert(topLeft, texture_size.x, y + vp_height + vt_height + vn_height, id);
        posOffset = get_vec3(topLeft, texture_size.x, y, index.x);
        texCoord = get_vec2(topLeft, texture_size.x, y + vp_height, index.y);
        vertexNormal = get_vec3(topLeft, texture_size.x, y + vp_height + vt_height, index.z);

        vec2 onePixel = 1. / atlasSize;
        //final uv (pos set manually)
        texCoord = (vec2(topLeft.x, topLeft.y + 1 + uv_height) + texCoord * texture_size) / atlasSize
                //make sure that faces with same uv beginning/ending renders
                + vec2(onePixel.x * 0.0001 * corner, onePixel.y * 0.0001 * ((corner + 1) % 4));
    }
}
