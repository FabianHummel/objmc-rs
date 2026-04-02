use argh::FromArgs;
use colored::Colorize;
use image::GenericImage;
use wavefront::Obj;

#[derive(FromArgs)]
/// A tool to convert .obj files into a format that can be used in Minecraft resource packs.
struct Args {
    /// path to the .obj file
    #[argh(option)]
    obj: String,

    /// path to the texture file
    #[argh(option)]
    texture: Option<String>,

    /// marker value (0-255) to identify the output texture, can be used in the shader to apply special effects
    #[argh(option)]
    marker: u8,

    /// path to save the output texture file (default: output.png)
    #[argh(option, default = "\"output.png\".to_string()")]
    output_texture: String,

    /// path to save the output model definition file (default: model.json)
    #[argh(option, default = "\"model.json\".to_string()")]
    output_model: String,
}

fn main() {
    // parse command line arguments
    let args: Args = argh::from_env();
    let obj_file = args.obj;
    let texture_file = args.texture;
    let marker_value = args.marker;
    let output_texture_file = args.output_texture;
    let output_model_file = args.output_model;

    // read .obj file
    println!("{}", "Loading .obj file...".bold());
    let obj = Obj::from_file(obj_file).expect("Failed to load .obj file");

    // read texture file
    let texture = texture_file.and_then(|texture_file| {
        println!("{}", "Reading texture file...".bold());
        Some(image::open(texture_file).expect("Failed to load texture file"))
    });

    let default_width = (obj.vertices().len() as u32 * 3).isqrt();
    let texture_width = texture.as_ref().map_or(default_width, |texture| texture.width());
    let texture_height = texture.as_ref().map_or(0, |texture| texture.height());

    println!("{}", "Model information:".bold());

    // calculate output image dimensions
    let num_triangles = obj.triangles().count() as u32;
    let uv_height = num_triangles.div_ceil(texture_width);
    println!(" ・ # faces: {}", num_triangles.to_string().cyan().bold());

    let num_vertices = obj.vertices().len() as u32;
    let vc_height = (num_vertices * 3).div_ceil(texture_width);
    println!(" ・ # vertex indices: {}", num_vertices.to_string().cyan().bold());

    let num_positions = obj.positions().len() as u32;
    let vp_height = (num_positions * 3).div_ceil(texture_width);
    println!(" ・ # vertices: {}", num_positions.to_string().cyan().bold());

    let num_uvs = obj.uvs().len() as u32;
    let vt_height = (num_uvs * 2).div_ceil(texture_width);
    println!(" ・ # uv coordinates: {}", num_uvs.to_string().cyan().bold());

    let num_normals = obj.normals().len() as u32;
    let vn_height = (num_normals * 3).div_ceil(texture_width);
    println!(" ・ # vertex normals: {}", num_normals.to_string().cyan().bold());

    let output_height = 1 + uv_height + texture_height + vc_height + vp_height + vt_height + vn_height;

    if output_height > 4096 && texture_width < 4096 || output_height > 8 * texture_width {
        println!("output height ({output_height}) may be too high, consider increasing width of input texture.");
    }

    println!("{}", "\nGenerating output image...".bold());

    // create output image
    let mut output_image = image::DynamicImage::new(
        texture_width, output_height, image::ColorType::Rgba8);

    // marker
    output_image.put_pixel(0, 0, image::Rgba([
        12, 34, 56, marker_value]));

    // texture size
    output_image.put_pixel(1, 0, image::Rgba([
        (texture_width >> 8) as u8,
        (texture_width & 0xFF) as u8,
        (texture_height >> 8) as u8,
        (texture_height & 0xFF) as u8]));

    // data heights
    output_image.put_pixel(2, 0, image::Rgba([
        ((uv_height >> 8) & 0xFF) as u8,
        (uv_height & 0xFF) as u8,
        ((vc_height >> 8) & 0xFF) as u8,
        (vc_height & 0xFF) as u8]));
    output_image.put_pixel(3, 0, image::Rgba([
        ((vp_height >> 8) & 0xFF) as u8,
        (vp_height & 0xFF) as u8,
        ((vt_height >> 8) & 0xFF) as u8,
        (vt_height & 0xFF) as u8]));

    // texture
    if let Some(texture) = &texture {
        output_image.copy_from(texture, 0, 1 + uv_height)
            .expect("Failed to copy texture to output image");
    }

    // generate json model definition
    let model_definition = generate_model_definition(
        &output_texture_file,
        &mut output_image,
        num_triangles,
        texture_width,
        output_height);

    // save model definition
    std::fs::write(&output_model_file, serde_json::to_string(&model_definition).unwrap())
        .expect("Failed to save model definition");

    let mut y_offset = 1 + uv_height + texture_height;

    // vertex indices
    for (i, value) in obj.vertices().flat_map(flatten_vertex).enumerate() {
        write_int(&mut output_image, i as u32, y_offset, texture_width, value);
    }
    y_offset += vc_height;

    // vertex positions
    for (i, &value) in obj.positions().iter().flatten().enumerate() {
        let encoded = 8388608.0 + value * 65536.0;
        write_float(&mut output_image, i as u32, y_offset, texture_width, encoded);
    }
    y_offset += vp_height;

    // uv coordinates
    for (i, &value) in obj.uvs().iter().map(|uv| uv.iter().take(2)).flatten().enumerate() {
        let encoded = value * 65535.0;
        write_float(&mut output_image, i as u32, y_offset, texture_width, encoded);
    }
    y_offset += vt_height;

    // vertex normals
    for (i, &value) in obj.normals().iter().flatten().enumerate() {
        let encoded = 8388608.0 + value * 65536.0;
        write_float(&mut output_image, i as u32, y_offset, texture_width, encoded);
    }

    // save output image
    output_image.save(&output_texture_file)
        .expect("Failed to save output image");

    println!("\n{} {}", "Done!".bold().green(), format!("Output saved as {} and {}", &output_texture_file, &output_model_file));
}

#[inline]
fn write_int(image: &mut image::DynamicImage, index: u32, offset: u32, texture_width: u32, value: u32) {
    let x = index % texture_width;
    let y = offset + index / texture_width;

    image.put_pixel(x, y, image::Rgba([
        ((value >> 16) & 0xFF) as u8,
        ((value >> 8) & 0xFF) as u8,
        (value & 0xFF) as u8,
        255]));
}

#[inline]
fn write_float(image: &mut image::DynamicImage, index: u32, offset: u32, texture_width: u32, value: f32) {
    let x = index % texture_width;
    let y = offset + index / texture_width;

    image.put_pixel(x, y, image::Rgba([
        ((value / 65536.0) % 256.0) as u8,
        ((value / 256.0) % 256.0) as u8,
        (value % 256.0) as u8,
        255]));
}

fn flatten_vertex(vertex: wavefront::Vertex) -> [u32; 3] {
    [
        vertex.position_index() as u32,
        vertex.uv_index().unwrap_or(0) as u32,
        vertex.normal_index().unwrap_or(0) as u32,
    ]
}

fn generate_model_definition(
    output_texture_file: &String,
    output_image: &mut image::DynamicImage,
    num_triangles: u32,
    texture_width: u32,
    output_height: u32,
) -> serde_json::Value {
    // convert output texture path to model definition format
    // if the format is not recognized, use the file name as is
    let texture_path = output_texture_file.strip_prefix("src/assets/")
        .and_then(|p| p.strip_suffix(".png"))
        .and_then(|p| {
            let mut parts = p.splitn(3, '/');
            let namespace = parts.next()?;
            let folder = parts.next()?;
            let rest = parts.next()?;

            if folder != "textures" {
                return None;
            }

            Some(format!("{namespace}:{rest}"))
        })
        .unwrap_or(output_texture_file.clone());

    // base model definition
    let mut model_definition = serde_json::json!({
        "textures": {"0": texture_path},
        "elements": [],
        "display": {
            "thirdperson_righthand": {"rotation": [85, 0, 0]},
            "thirdperson_lefthand": {"rotation": [85, 0, 0]},
        }
    });

    let elements = model_definition
        .as_object_mut().unwrap()
        .get_mut("elements").unwrap()
        .as_array_mut().unwrap();

    // for each triangle, add an element to the model definition with the corresponding UV coordinates
    for i in 0..num_triangles {
        elements.push(serde_json::json!({
            "from": [8, 0, 8],
            "to": [24, 16, 8],
            "faces": {
                "north": {
                    // get uv coordinates for this triangle from the output image (used for calculating the top-left)
                    "uv": get_uv_offset(output_image, i, texture_width, output_height),
                    "texture": "#0",
                    "tintindex": 0,
                }
            },
        }));
    }

    model_definition
}

fn get_uv_offset(image: &mut image::DynamicImage, index: u32, texture_width: u32, output_height: u32) -> [f32; 4] {
    let x = index % texture_width;
    let y = 1 + index / texture_width;

    image.put_pixel(x, y, image::Rgba([
        ((x >> 8) & 0xFF) as u8,
        (x & 0xFF) as u8,
        ((y >> 8) & 0xFF) as u8,
        (y & 0xFF) as u8]));
    [
        (x as f32 + 0.1) * 16.0 / texture_width as f32,
        (y as f32 + 0.1) * 16.0 / output_height as f32,
        (x as f32 + 0.9) * 16.0 / texture_width as f32,
        (y as f32 + 0.9) * 16.0 / output_height as f32,
    ]
}