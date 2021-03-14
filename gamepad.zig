const std = @import("std");
const bb = @import("bb.zig");

pub const GamepadButtons = struct {
    dpad_up: bool = false,
    dpad_down: bool = false,
    dpad_left: bool = false,
    dpad_right: bool = false,
    start: bool = false,
    back: bool = false,
    left_stick: bool = false,
    right_stick: bool = false,
    left_shoulder: bool = false,
    right_shoulder: bool = false,
    face_bottom: bool = false,
    face_right: bool = false,
    face_left: bool = false,
    face_top: bool = false,
    left_trigger: bool = false,
    right_trigger: bool = false,
};

pub const GamepadState = struct {
    buttons: GamepadButtons = GamepadButtons{},
    left_trigger: f32 = 0,
    right_trigger: f32 = 0,
    left_stick_horiz: f32 = 0,
    left_stick_vert: f32 = 0,
    right_stick_horiz: f32 = 0,
    right_stick_vert: f32 = 0,
    connected: bool = false,
};

const XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE: c_short = 7849;
const XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE: c_short = 8689;
const XINPUT_GAMEPAD_TRIGGER_THRESHOLD: u8 = 30;

const XINPUT_GAMEPAD = struct {
    wButtons: c_ushort = 0,
    bLeftTrigger: u8 = 0,
    bRightTrigger: u8 = 0,
    sThumbLX: c_short = 0,
    sThumbLY: c_short = 0,
    sThumbRX: c_short = 0,
    sThumbRY: c_short = 0,
};

const XINPUT_STATE = struct {
    dwPacketNumber: c_ulong = 0,
    Gamepad: XINPUT_GAMEPAD = XINPUT_GAMEPAD{},
};

var xinput_state: XINPUT_STATE = XINPUT_STATE{};
pub var state: GamepadState = GamepadState{};

const XInputButtons = enum {
    dpad_up,
    dpad_down,
    dpad_left,
    dpad_right,
    start,
    back,
    left_stick,
    right_stick,
    left_shoulder,
    right_shoulder,
    unused0,
    unused1,
    face_bottom,
    face_right,
    face_left,
    face_top,
};

fn axis_i16_to_f32(in: c_short, deadzone: c_short) f32 {
    if (in > -deadzone and in < deadzone) return 0.0;
    const denominator: f32 = if (in <= 0) 32768.0 else 32767.0;
    return @intToFloat(f32, in) / denominator;
}

fn build_gamepad_state() void {
    const src = xinput_state.Gamepad;
    state.connected = true;
    const buttons_info = @typeInfo(GamepadButtons);
    inline for (buttons_info.Struct.fields) |field| {
        inline for (@typeInfo(XInputButtons).Enum.fields) |enum_field, enum_index| {
            if (std.mem.eql(u8, field.name, enum_field.name)) {
                @field(state.buttons, field.name) = src.wButtons & (1 << enum_index) != 0;
            }
        }
    }
    state.left_trigger = @intToFloat(f32, src.bLeftTrigger) / 255.0;
    state.right_trigger = @intToFloat(f32, src.bRightTrigger) / 255.0;
    state.buttons.left_trigger = src.bLeftTrigger > XINPUT_GAMEPAD_TRIGGER_THRESHOLD;
    state.buttons.right_trigger = src.bRightTrigger > XINPUT_GAMEPAD_TRIGGER_THRESHOLD;
    state.left_stick_horiz = axis_i16_to_f32(src.sThumbLX, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
    state.left_stick_vert = axis_i16_to_f32(src.sThumbLY, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
    state.right_stick_horiz = axis_i16_to_f32(src.sThumbRX, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
    state.right_stick_vert = axis_i16_to_f32(src.sThumbRY, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
}

pub const INVALID_HMODULE_VALUE = @intToPtr(std.os.windows.HMODULE, std.math.maxInt(usize));
var hmodule_xinput: std.os.windows.HMODULE = INVALID_HMODULE_VALUE;
var XInputGetState: ?fn (c_ulong, *XINPUT_STATE) callconv(.Stdcall) c_ulong = null;

pub fn init() void {
    hmodule_xinput = std.os.windows.LoadLibraryW(comptime std.unicode.utf8ToUtf16LeStringLiteral("xinput_1_4.dll")) catch INVALID_HMODULE_VALUE;
    if (hmodule_xinput != INVALID_HMODULE_VALUE) {
        bb.log("xinput", "using xinput_1_4.dll", .{});
    } else {
        hmodule_xinput = std.os.windows.LoadLibraryW(comptime std.unicode.utf8ToUtf16LeStringLiteral("xinput_1_3.dll")) catch INVALID_HMODULE_VALUE;
        if (hmodule_xinput != INVALID_HMODULE_VALUE) {
            bb.log("xinput", "using xinput_1_3.dll", .{});
        } else {
            hmodule_xinput = std.os.windows.LoadLibraryW(comptime std.unicode.utf8ToUtf16LeStringLiteral("xinput9_1_0.dll")) catch INVALID_HMODULE_VALUE;
            if (hmodule_xinput != INVALID_HMODULE_VALUE) {
                bb.log("xinput", "using xinput9_1_0.dll", .{});
            } else {
                bb.warning("xinput", "failed to find xinput dll", .{});
            }
        }
    }

    var ret = std.os.windows.kernel32.GetProcAddress(hmodule_xinput, "XInputGetState");
    if (ret != null) {
        var intret = @ptrToInt(ret.?);
        XInputGetState = @intToPtr(fn (c_ulong, *XINPUT_STATE) callconv(.Stdcall) c_ulong, intret);
    }
}

pub fn shutdown() void {
    if (hmodule_xinput != INVALID_HMODULE_VALUE) {
        std.os.windows.FreeLibrary(hmodule_xinput);
        hmodule_xinput = INVALID_HMODULE_VALUE;
    }
}

pub fn update(dt: f64) void {
    state = GamepadState{};
    if (XInputGetState != null) {
        const ret = XInputGetState.?(0, &xinput_state);
        if (ret == 0) {
            build_gamepad_state();
            //bb.very_verbose("xinput", "{}", .{xinput_state});
            //bb.verbose("xinput", "{}", .{state});
        }
    }
}
