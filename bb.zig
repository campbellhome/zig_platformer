const c = @import("c.zig");
const std = @import("std");

pub inline fn very_verbose(category: [*c]const u8, comptime format: []const u8, args: anytype) void {
    var buffer = [_]u8{0} ** 1024;
    const buffer_slice = buffer[0..];
    const text = std.fmt.bufPrint(buffer_slice, format, args) catch "fmt failed";
    c.bb_trace_dynamic_preformatted("zig", 0, category, c.bb_log_level_e.kBBLogLevel_VeryVerbose, 0, text.ptr);
}

pub inline fn verbose(category: [*c]const u8, comptime format: []const u8, args: anytype) void {
    var buffer = [_]u8{0} ** 1024;
    const buffer_slice = buffer[0..];
    const text = std.fmt.bufPrint(buffer_slice, format, args) catch "fmt failed";
    c.bb_trace_dynamic_preformatted("zig", 0, category, c.bb_log_level_e.kBBLogLevel_Verbose, 0, text.ptr);
}

pub inline fn log(category: [*c]const u8, comptime format: []const u8, args: anytype) void {
    var buffer = [_]u8{0} ** 1024;
    const buffer_slice = buffer[0..];
    const text = std.fmt.bufPrint(buffer_slice, format, args) catch "fmt failed";
    c.bb_trace_dynamic_preformatted("zig", 0, category, c.bb_log_level_e.kBBLogLevel_Log, 0, text.ptr);
}

pub inline fn display(category: [*c]const u8, comptime format: []const u8, args: anytype) void {
    var buffer = [_]u8{0} ** 1024;
    const buffer_slice = buffer[0..];
    const text = std.fmt.bufPrint(buffer_slice, format, args) catch "fmt failed";
    c.bb_trace_dynamic_preformatted("zig", 0, category, c.bb_log_level_e.kBBLogLevel_Display, 0, text.ptr);
}

pub inline fn warning(category: [*c]const u8, comptime format: []const u8, args: anytype) void {
    var buffer = [_]u8{0} ** 1024;
    const buffer_slice = buffer[0..];
    const text = std.fmt.bufPrint(buffer_slice, format, args) catch "fmt failed";
    c.bb_trace_dynamic_preformatted("zig", 0, category, c.bb_log_level_e.kBBLogLevel_Warning, 0, text.ptr);
}

pub inline fn err(category: [*c]const u8, comptime format: []const u8, args: anytype) void {
    var buffer = [_]u8{0} ** 1024;
    const buffer_slice = buffer[0..];
    const text = std.fmt.bufPrint(buffer_slice, format, args) catch "fmt failed";
    c.bb_trace_dynamic_preformatted("zig", 0, category, c.bb_log_level_e.kBBLogLevel_Error, 0, text.ptr);
}
