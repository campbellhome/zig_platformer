const std = @import("std");
const c = @import("c.zig");
pub const zlm_specializeOn = @import("zlm/zlm-generic.zig").specializeOn;
usingnamespace zlm_specializeOn(f32);
const AABB = @import("aabb.zig").AABB;
const Room = @import("room.zig").Room;
const Color = @import("color.zig").Color;
const allocators = @import("allocators.zig");

pub const depth = struct {
    pub const far: f32 = 0;
    pub const bg: f32 = 0;
    pub const tile: f32 = 1;
    pub const player: f32 = 2;
    pub const player_trail: f32 = 1.8;
    pub const fade: f32 = 10;
};

pub const Images = enum {
    white,
    checkerboard,
    tile_gray,
    guy_atlas,
    guy_stand,
    guy_run1,
    guy_run2,
    guy_jump,
    guy_hang,
    guy_climb1,
    guy_climb2,
};

const Image = struct {
    id: c.sg_image,
    uv0: Vec2,
    uv1: Vec2,
};

const State = struct {
    img: c.sg_image,
    images: [@typeInfo(Images).Enum.fields.len]Image,
    pip_3d: c.sgl_pipeline,
    screen_width: i32,
    screen_height: i32,
    size: Vec2,
};

var state: State = undefined;

fn make_white() Image {
    const a: u32 = 0xFFFFFFFF;
    const pixels = [8][8]u32{
        [_]u32{ a, a, a, a, a, a, a, a },
        [_]u32{ a, a, a, a, a, a, a, a },
        [_]u32{ a, a, a, a, a, a, a, a },
        [_]u32{ a, a, a, a, a, a, a, a },
        [_]u32{ a, a, a, a, a, a, a, a },
        [_]u32{ a, a, a, a, a, a, a, a },
        [_]u32{ a, a, a, a, a, a, a, a },
        [_]u32{ a, a, a, a, a, a, a, a },
    };
    var sg_image_desc = std.mem.zeroes(c.sg_image_desc);
    sg_image_desc.width = 8;
    sg_image_desc.height = 8;
    sg_image_desc.wrap_u = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.wrap_v = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.pixel_format = .SG_PIXELFORMAT_RGBA8;
    sg_image_desc.content.subimage[0][0].ptr = &pixels[0][0];
    sg_image_desc.content.subimage[0][0].size = 4 * 8 * 8;
    return Image{ .id = c.sg_make_image(&sg_image_desc), .uv0 = Vec2{ .x = -1, .y = -1 }, .uv1 = Vec2{ .x = 1, .y = 1 } };
}

fn make_checkerboard() Image {
    const a: u32 = 0xFFFFFFFF;
    const b: u32 = 0x00000000;
    const pixels = [8][8]u32{
        [_]u32{ a, b, a, b, a, b, a, b },
        [_]u32{ b, a, b, a, b, a, b, a },
        [_]u32{ a, b, a, b, a, b, a, b },
        [_]u32{ b, a, b, a, b, a, b, a },
        [_]u32{ a, b, a, b, a, b, a, b },
        [_]u32{ b, a, b, a, b, a, b, a },
        [_]u32{ a, b, a, b, a, b, a, b },
        [_]u32{ b, a, b, a, b, a, b, a },
    };
    var sg_image_desc = std.mem.zeroes(c.sg_image_desc);
    sg_image_desc.width = 8;
    sg_image_desc.height = 8;
    sg_image_desc.wrap_u = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.wrap_v = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.pixel_format = .SG_PIXELFORMAT_RGBA8;
    sg_image_desc.content.subimage[0][0].ptr = &pixels[0][0];
    sg_image_desc.content.subimage[0][0].size = 4 * 8 * 8;
    return Image{ .id = c.sg_make_image(&sg_image_desc), .uv0 = Vec2{ .x = 0, .y = 0 }, .uv1 = Vec2{ .x = 1, .y = 1 } };
}

const tile_gray_data = @embedFile("data/tile_gray.png");
fn make_tile_gray() Image {
    const desired_channels: i32 = 4;
    var width: i32 = 0;
    var height: i32 = 0;
    var num_channels: i32 = 0;
    const pixels = c.stbi_load_from_memory(&tile_gray_data[0], tile_gray_data.len, &width, &height, &num_channels, desired_channels);
    if (pixels == null) {
        return make_white();
    }

    defer c.stbi_image_free(pixels);
    var sg_image_desc = std.mem.zeroes(c.sg_image_desc);
    sg_image_desc.width = width;
    sg_image_desc.height = height;
    sg_image_desc.wrap_u = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.wrap_v = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.pixel_format = .SG_PIXELFORMAT_RGBA8;
    sg_image_desc.content.subimage[0][0].ptr = pixels;
    sg_image_desc.content.subimage[0][0].size = num_channels * width * height;
    return Image{ .id = c.sg_make_image(&sg_image_desc), .uv0 = Vec2{ .x = 0, .y = 0 }, .uv1 = Vec2{ .x = 1, .y = 1 } };
}

const guy_atlas_data = @embedFile("data/guy_atlas.png");
fn make_guy_atlas() Image {
    const desired_channels: i32 = 4;
    var width: i32 = 0;
    var height: i32 = 0;
    var num_channels: i32 = 0;
    const pixels = c.stbi_load_from_memory(&guy_atlas_data[0], guy_atlas_data.len, &width, &height, &num_channels, desired_channels);
    if (pixels == null) {
        return make_white();
    }

    defer c.stbi_image_free(pixels);
    var sg_image_desc = std.mem.zeroes(c.sg_image_desc);
    sg_image_desc.width = width;
    sg_image_desc.height = height;
    sg_image_desc.wrap_u = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.wrap_v = .SG_WRAP_CLAMP_TO_EDGE;
    sg_image_desc.pixel_format = .SG_PIXELFORMAT_RGBA8;
    sg_image_desc.content.subimage[0][0].ptr = pixels;
    sg_image_desc.content.subimage[0][0].size = num_channels * width * height;
    return Image{ .id = c.sg_make_image(&sg_image_desc), .uv0 = Vec2{ .x = 0, .y = 0 }, .uv1 = Vec2{ .x = 1, .y = 1 } };
}

// 4x4 gap, 16x32
fn guy_image(row: f32, col: f32) Image {
    const top = 4 + row * (32 + 4);
    const bottom = top + 32;
    const left = 4 + col * (16 + 4);
    const right = left + 16;
    const width: f32 = 256;
    const height: f32 = 256;
    return Image{ .id = state.images[@enumToInt(Images.guy_atlas)].id, .uv0 = Vec2{ .x = left / width, .y = top / width }, .uv1 = Vec2{ .x = right / width, .y = bottom / width } };
}

fn make_guy_stand() Image {
    return guy_image(0, 0);
}

fn make_guy_run1() Image {
    return guy_image(0, 1);
}

fn make_guy_run2() Image {
    return guy_image(0, 2);
}

fn make_guy_jump() Image {
    return guy_image(0, 3);
}

fn make_guy_hang() Image {
    return guy_image(0, 4);
}

fn make_guy_climb1() Image {
    return guy_image(0, 5);
}

fn make_guy_climb2() Image {
    return guy_image(0, 6);
}

pub fn init() void {
    state.images[@enumToInt(Images.white)] = make_white();
    state.images[@enumToInt(Images.checkerboard)] = make_checkerboard();
    state.images[@enumToInt(Images.tile_gray)] = make_tile_gray();
    state.images[@enumToInt(Images.guy_atlas)] = make_guy_atlas();
    state.images[@enumToInt(Images.guy_stand)] = make_guy_stand();
    state.images[@enumToInt(Images.guy_run1)] = make_guy_run1();
    state.images[@enumToInt(Images.guy_run2)] = make_guy_run2();
    state.images[@enumToInt(Images.guy_jump)] = make_guy_jump();
    state.images[@enumToInt(Images.guy_hang)] = make_guy_hang();
    state.images[@enumToInt(Images.guy_climb1)] = make_guy_climb1();
    state.images[@enumToInt(Images.guy_climb2)] = make_guy_climb2();

    var sg_pipeline_desc = std.mem.zeroes(c.sg_pipeline_desc);
    sg_pipeline_desc.depth_stencil.depth_write_enabled = true;
    sg_pipeline_desc.depth_stencil.depth_compare_func = c.sg_compare_func.SG_COMPAREFUNC_LESS_EQUAL;
    sg_pipeline_desc.rasterizer.cull_mode = c.sg_cull_mode.SG_CULLMODE_BACK;
    sg_pipeline_desc.blend.enabled = true;
    //sg_pipeline_desc.blend.src_factor_rgb = .SG_BLENDFACTOR_SRC_COLOR;
    //sg_pipeline_desc.blend.dst_factor_rgb = .SG_BLENDFACTOR_ONE_MINUS_SRC_COLOR;
    sg_pipeline_desc.blend.src_factor_rgb = .SG_BLENDFACTOR_SRC_ALPHA;
    sg_pipeline_desc.blend.dst_factor_rgb = .SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    //sg_pipeline_desc.blend.op_rgb = .SG_BLENDOP_ADD;
    //sg_pipeline_desc.blend.src_factor_alpha = .SG_BLENDFACTOR_SRC_ALPHA;
    //sg_pipeline_desc.blend.dst_factor_alpha = .SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    //sg_pipeline_desc.blend.op_alpha = .SG_BLENDOP_ADD;
    state.pip_3d = c.sgl_make_pipeline(&sg_pipeline_desc);
}

// typedef struct sg_blend_state {
//     bool enabled;
//     sg_blend_factor src_factor_rgb;
//     sg_blend_factor dst_factor_rgb;
//     sg_blend_op op_rgb;
//     sg_blend_factor src_factor_alpha;
//     sg_blend_factor dst_factor_alpha;
//     sg_blend_op op_alpha;
//     uint8_t color_write_mask;
//     int color_attachment_count;
//     sg_pixel_format color_format;
//     sg_pixel_format depth_format;
//     float blend_color[4];
// } sg_blend_state;

pub fn shutdown() void {
    c.sgl_shutdown();
}

var queued_images: std.ArrayList(QueuedImage) = undefined;

pub fn begin_frame() void {
    state.screen_width = c.sapp_width();
    state.screen_height = c.sapp_height();
    state.size = Vec2{ .x = Room.DefaultCameraWidth, .y = Room.DefaultCameraHeight };
    set_defaults();

    queued_images = std.ArrayList(QueuedImage).init(&allocators.frame_arena.allocator);
}

pub fn end_frame() void {
    render_queued_images(queued_images);
    c.sgl_draw();
}

const Camera = struct {
    pos: Vec2,
    scale: f32,
    zoom: f32,
};

var g_camera = Camera{ .pos = Vec2.zero, .scale = 1, .zoom = 1 };

pub fn set_room_dimensions(camera_pos: Vec2, zoom: f32) void {
    g_camera.pos = camera_pos;
    const clamped_zoom = if (zoom <= 0.1) 0.1 else zoom;
    const scale = 1 / clamped_zoom;
    g_camera.scale = scale;
    g_camera.zoom = clamped_zoom;
}

fn set_defaults() void {
    c.sgl_defaults();
    c.sgl_load_pipeline(state.pip_3d);

    c.sgl_viewport(0, 0, state.screen_width, state.screen_height, true);
    c.sgl_matrix_mode_projection();
    c.sgl_ortho(0, state.size.x, 0, state.size.y, -10, 10);
    c.sgl_matrix_mode_modelview();
    c.sgl_lookat(0, 0, 10, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);
    c.sgl_matrix_mode_texture();
    c.sgl_rotate(0.0, 0.0, 0.0, 1.0);
    c.sgl_scale(1.0, 1.0, 1.0);
}

pub fn image(screen_center: Vec2, screen_extents: Vec2, image_depth: f32, color: Color, imageName: Images) void {
    if (color.a <= 0) return;

    const data = state.images[@enumToInt(imageName)];

    c.sgl_enable_texture();
    c.sgl_texture(data.id);

    c.sgl_begin_quads();
    c.sgl_c3f(@intToFloat(f32, color.r) / 255, @intToFloat(f32, color.g) / 255, @intToFloat(f32, color.b) / 255);

    const x0 = screen_center.x - screen_extents.x;
    const x1 = screen_center.x + screen_extents.x;
    const y0 = screen_center.y - screen_extents.y;
    const y1 = screen_center.y + screen_extents.y;

    c.sgl_v3f_t2f(x0, y1, image_depth, data.uv0.x, data.uv0.y);
    c.sgl_v3f_t2f(x0, y0, image_depth, data.uv0.x, data.uv1.y);
    c.sgl_v3f_t2f(x1, y0, image_depth, data.uv1.x, data.uv1.y);
    c.sgl_v3f_t2f(x1, y1, image_depth, data.uv1.x, data.uv0.y);

    c.sgl_end();
}

pub fn room_image(room: Room, room_center: Vec2, room_extents: Vec2, image_depth: f32, color: Color, imageName: Images) void {
    room_image_reversible(room, room_center, room_extents, image_depth, color, imageName, false);
}

const QueuedImage = struct {
    imageName: Images,
    color: Color,
    p0: Vec2,
    p1: Vec2,
    uv0: Vec2,
    uv1: Vec2,
    depth: f32,
};

pub fn room_image_reversible(room: Room, room_center: Vec2, room_extents: Vec2, image_depth: f32, color: Color, imageName: Images, reverse: bool) void {
    if (color.a <= 0) return;

    const camera = g_camera;
    const size = Vec2.scale(state.size, 0.5 * camera.scale);
    const bounds = AABB{ .center = camera.pos, .extents = size };
    const min = bounds.min();

    const scaled_extents = Vec2.scale(room_extents, camera.zoom);
    const p0 = Vec2.scale(Vec2.sub(Vec2.sub(room_center, room_extents), min), camera.zoom);
    const p1 = Vec2.scale(Vec2.sub(Vec2.add(room_center, room_extents), min), camera.zoom);

    const data = state.images[@enumToInt(imageName)];
    const uv0 = Vec2{ .x = if (reverse) data.uv1.x else data.uv0.x, .y = data.uv0.y };
    const uv1 = Vec2{ .x = if (reverse) data.uv0.x else data.uv1.x, .y = data.uv1.y };

    queued_images.append(QueuedImage{ .imageName = imageName, .color = color, .p0 = p0, .p1 = p1, .uv0 = uv0, .uv1 = uv1, .depth = image_depth }) catch return;
}

fn depth_compare(context: void, a: QueuedImage, b: QueuedImage) bool {
    return a.depth < b.depth;
}

fn render_queued_images(images: std.ArrayList(QueuedImage)) void {
    std.sort.sort(QueuedImage, images.items, {}, depth_compare);
    c.sgl_enable_texture();
    for (images.items) |data| {
        const image_data = state.images[@enumToInt(data.imageName)];
        c.sgl_texture(image_data.id);

        c.sgl_begin_quads();
        c.sgl_c4f(data.color.r, data.color.g, data.color.b, data.color.a);

        c.sgl_v3f_t2f(data.p0.x, data.p1.y, data.depth, data.uv0.x, data.uv0.y);
        c.sgl_v3f_t2f(data.p0.x, data.p0.y, data.depth, data.uv0.x, data.uv1.y);
        c.sgl_v3f_t2f(data.p1.x, data.p0.y, data.depth, data.uv1.x, data.uv1.y);
        c.sgl_v3f_t2f(data.p1.x, data.p1.y, data.depth, data.uv1.x, data.uv0.y);

        c.sgl_end();
    }
}
