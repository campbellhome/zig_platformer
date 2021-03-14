const std = @import("std");
const c = @import("c.zig");
const bb = @import("bb.zig");
const gamepad = @import("gamepad.zig");

const MaxActionKeycodes = 4;
const Action = enum {
    up,
    left,
    down,
    right,
    jump,
    dash,
    grab,
    controls_ui,
    debug_ui,
    tweak_ui,
    quick_restart,

    pub fn isToggle(this: Action) bool {
        return this == .controls_ui or this == .debug_ui or this == .tweak_ui;
    }
};

pub const GameInput = struct {
    keycodes: [@typeInfo(Action).Enum.fields.len][MaxActionKeycodes]c.sapp_keycode = [@typeInfo(Action).Enum.fields.len][MaxActionKeycodes]c.sapp_keycode{
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_UP, c.sapp_keycode.SAPP_KEYCODE_W, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_LEFT, c.sapp_keycode.SAPP_KEYCODE_A, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_DOWN, c.sapp_keycode.SAPP_KEYCODE_S, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_RIGHT, c.sapp_keycode.SAPP_KEYCODE_D, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_C, c.sapp_keycode.SAPP_KEYCODE_SPACE, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_X, c.sapp_keycode.SAPP_KEYCODE_LEFT_CONTROL, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_Z, c.sapp_keycode.SAPP_KEYCODE_V, c.sapp_keycode.SAPP_KEYCODE_LEFT_SHIFT, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_F1, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_F2, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_F3, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
        [_]c.sapp_keycode{ c.sapp_keycode.SAPP_KEYCODE_R, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID, c.sapp_keycode.SAPP_KEYCODE_INVALID },
    },
    pressed: [@typeInfo(Action).Enum.fields.len][MaxActionKeycodes]bool = [@typeInfo(Action).Enum.fields.len][MaxActionKeycodes]bool{
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
        [_]bool{false} ** MaxActionKeycodes,
    },

    up: bool = false,
    left: bool = false,
    down: bool = false,
    right: bool = false,
    jump: bool = false,
    dash: bool = false,
    grab: bool = false,
    controls_ui: bool = false,
    debug_ui: bool = false,
    tweak_ui: bool = false,
    quick_restart: bool = false,
    left_stick_horiz: f32 = 0.0,
    left_stick_vert: f32 = 0.0,

    fn is_pressed(this: GameInput, action: Action) bool {
        for (this.pressed[@enumToInt(action)]) |pressed| {
            if (pressed) {
                return true;
            }
        }
        return false;
    }

    pub fn event(this: *GameInput, e: [*c]const c.sapp_event) void {
        if (e.*.type == c.sapp_event_type.SAPP_EVENTTYPE_KEY_DOWN or e.*.type == c.sapp_event_type.SAPP_EVENTTYPE_KEY_UP) {
            const pressed = e.*.type == c.sapp_event_type.SAPP_EVENTTYPE_KEY_DOWN;

            var matched_actions: [@typeInfo(Action).Enum.fields.len]bool = [_]bool{false} ** @typeInfo(Action).Enum.fields.len;

            for (this.keycodes) |row, i| {
                for (row) |keycode, j| {
                    if (keycode == e.*.key_code) {
                        this.pressed[i][j] = pressed;
                        matched_actions[i] = true;
                    }
                }
            }

            if (pressed) {
                if (matched_actions[@enumToInt(Action.controls_ui)]) {
                    this.controls_ui = !this.controls_ui;
                } else if (matched_actions[@enumToInt(Action.debug_ui)]) {
                    this.debug_ui = !this.debug_ui;
                } else if (matched_actions[@enumToInt(Action.tweak_ui)]) {
                    this.tweak_ui = !this.tweak_ui;
                }
            }
        }
    }

    pub fn update(this: *GameInput, dt: f64) void {
        this.up = this.is_pressed(Action.up);
        this.left = this.is_pressed(Action.left);
        this.down = this.is_pressed(Action.down);
        this.right = this.is_pressed(Action.right);
        this.jump = this.is_pressed(Action.jump);
        this.dash = this.is_pressed(Action.dash);
        this.grab = this.is_pressed(Action.grab);
        this.quick_restart = this.is_pressed(Action.quick_restart);

        if (gamepad.state.connected) {
            const buttons = gamepad.state.buttons;
            this.jump = this.jump or buttons.face_bottom or buttons.face_top;
            this.dash = this.dash or buttons.face_left or buttons.face_right;
            this.grab = this.grab or buttons.left_shoulder or buttons.right_shoulder or buttons.left_trigger or buttons.right_trigger;
            this.left_stick_horiz = gamepad.state.left_stick_horiz;
            this.left_stick_vert = gamepad.state.left_stick_vert;
        } else {
            this.left_stick_horiz = 0;
            this.left_stick_vert = 0;
        }
    }

    pub fn draw_controls_ui(this: GameInput) void {
        const info = @typeInfo(GameInput);
        inline for (info.Struct.fields) |field| {
            inline for (@typeInfo(Action).Enum.fields) |enum_field, enum_index| {
                if (std.mem.eql(u8, field.name, enum_field.name)) {
                        const pressed = @field(this, field.name);

                        var buffer: [1024]u8 = undefined;
                        const buffer_slice = buffer[0..];
                        const text = std.fmt.bufPrint(buffer_slice, "{} {}", .{field.name, pressed}) catch "fmt failed";
                        _ = c.igTextUnformatted(text.ptr, null);

                    //@field(state.buttons, field.name) = src.wButtons & (1 << enum_index) != 0;
                    // var buffer: [1024]u8 = undefined;
                    // const buffer_slice = buffer[0..];
                    // const text = std.fmt.bufPrint(buffer_slice, "{}", .{field}) catch "fmt failed";
                    // _ = c.igTextUnformatted(text.ptr, null);
                }
            }
        }

        // for (this.keycodes) |row, i| {
        //     for (row) |keycode, j| {
        //         if (keycode == e.*.key_code) {
        //             var buffer: [1024]u8 = undefined;
        //             const buffer_slice = buffer[0..];
        //             const text = std.fmt.bufPrint(buffer_slice, "{}", .{row.name}) catch "fmt failed";
        //             _ = c.igTextUnformatted(text.ptr, null);
        //             this.pressed[i][j] = pressed;
        //             matched_actions[i] = true;
        //         }
        //     }
        // }

        {
            var buffer: [1024]u8 = undefined;
            const buffer_slice = buffer[0..];
            const text = std.fmt.bufPrint(buffer_slice, "{}", .{this}) catch "fmt failed";
            _ = c.igTextUnformatted(text.ptr, null);
        }
        // _ = c.igText("input up:%d left:%d down:%d right:%d jump:%d grab:%d duck:%d debug:%d", this.up, this.left, this.down, this.right, this.jump, this.grab, this.duck, this.debug);
    }
};
