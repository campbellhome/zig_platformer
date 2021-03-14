pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub const white = Color{ .r=1, .g=1, .b=1, .a=1 };

    pub fn make(r: f32, g: f32, b: f32) Color {
        return Color{ .r = r, .g = g, .b = b, .a = 1 };
    }

    pub fn make_alpha(r: f32, g: f32, b: f32, a: f32) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn make_gray(rgb: f32) Color {
        return Color{ .r = rgb, .g = rgb, .b = rgb, .a = 1 };
    }

    pub fn pack(this: Color) u32 {
        return (@floatToInt(u32, this.a / 255) << 24) | (@floatToInt(u32, this.b / 255) << 16) | (@floatToInt(u32, this.g / 255) << 8) | @floatToInt(u32, this.r / 255);
    }
};
