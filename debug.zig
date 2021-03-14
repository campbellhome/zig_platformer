const c = @import("c.zig");
const main = @import("main.zig");

pub fn controls_ui() bool {
    return main.input.controls_ui;
}

pub fn debug_ui() bool {
    return main.input.debug_ui;
}

pub fn tweak_ui() bool {
    return main.input.tweak_ui;
}

pub fn f32_slider(text: [*c]const u8, val: *f32, min: f32, max: f32, slow: f32, fast: f32, format: [*c]const u8, power: f32) void {
    _ = c.igPushItemWidth(96);
    _ = c.igPushIDPtr(val);
    _ = c.igInputFloat("##Input", val, slow, fast, format, c.ImGuiInputTextFlags_CharsDecimal | c.ImGuiInputTextFlags_EnterReturnsTrue | c.ImGuiInputTextFlags_AutoSelectAll);
    _ = c.igSameLine(0, 10);
    _ = c.igSliderFloat(text, val, min, max, format, power);
    _ = c.igPopID();
    _ = c.igPopItemWidth();
}

pub fn f64_slider(text: [*c]const u8, val: *f64, min: f32, max: f32, slow: f32, fast: f32, format: [*c]const u8, power: f32) void {
    var start = @floatCast(f32, val.*);
    _ = c.igPushItemWidth(96);
    _ = c.igPushIDPtr(val);
    _ = c.igInputFloat("##Input", &start, slow, fast, format, c.ImGuiInputTextFlags_CharsDecimal | c.ImGuiInputTextFlags_EnterReturnsTrue | c.ImGuiInputTextFlags_AutoSelectAll);
    _ = c.igSameLine(0, 10);
    _ = c.igSliderFloat(text, &start, min, max, format, power);
    _ = c.igPopID();
    _ = c.igPopItemWidth();
    val.* = @floatCast(f64, start);
}
