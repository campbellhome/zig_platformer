const std = @import("std");
const c = @import("c.zig");
const bb = @import("bb.zig");
const debug = @import("debug.zig");
const gamepad = @import("gamepad.zig");
const allocators = @import("allocators.zig");
const render = @import("render.zig");
const audio = @import("audio.zig");

const Room = @import("room.zig").Room;
const RoomTicker = @import("room.zig").RoomTicker;
const GameInput = @import("game_input.zig").GameInput;

var room_ticker: RoomTicker = undefined;
pub var input = GameInput{};

const State = struct {
    pass_action: c.sg_pass_action,
    main_pipeline: c.sg_pipeline,
    main_bindings: c.sg_bindings,
};

var state: State = undefined;
var last_time: u64 = 0;
var f: f32 = 0.0;

export fn init() void {
    allocators.init();
    allocators.frame_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var sg_desc = std.mem.zeroes(c.sg_desc);
    sg_desc.context = c.sapp_sgcontext();
    c.sg_setup(&sg_desc);
    c.stm_setup();

    var sgl_desc = std.mem.zeroes(c.sgl_desc_t);
    sgl_desc.sample_count = c.sapp_sample_count();
    c.sgl_setup(&sgl_desc);

    render.init();

    var imgui_desc = std.mem.zeroes(c.simgui_desc_t);
    c.simgui_setup(&imgui_desc);

    state.pass_action.colors[0].action = .SG_ACTION_CLEAR;
    state.pass_action.colors[0].val = [_]f32{ 0.0, 0.0, 0.0, 1.0 };

    gamepad.init();

    audio.init();

    room_ticker = RoomTicker.init();
    allocators.frame_arena.deinit();
}

export fn update() void {
    allocators.frame_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer allocators.frame_arena.deinit();

    const width = c.sapp_width();
    const height = c.sapp_height();
    const dt = c.stm_sec(c.stm_laptime(&last_time));
    c.simgui_new_frame(width, height, dt);
    render.begin_frame();
    gamepad.update(dt);
    input.update(dt);
    if (debug.debug_ui()) {
        c.igText("Application average %.3f ms/frame (%.1f FPS)", dt, 1.0 / dt);
    }

    room_ticker.sim(dt, input);
    room_ticker.draw(dt);

    audio.update(dt);

    c.sg_begin_default_pass(&state.pass_action, width, height);
    render.end_frame();
    c.simgui_render();
    c.sg_end_pass();
    c.sg_commit();
    c.bb_tick();
}

export fn cleanup() void {
    audio.shutdown();
    render.shutdown();
    c.simgui_shutdown();
    c.sg_shutdown();
    gamepad.shutdown();
    allocators.deinit();
}

export fn event(e: [*c]const c.sapp_event) void {
    _ = c.simgui_handle_event(e);
    input.event(e);
}

// if (c.igIsMouseDown(c.ImGuiMouseButton_Left)) {
//     this.boxes[0].bounds.center = fromImVec2(c.igGetIO().*.MousePos);
// }

pub fn main() void {
    c.bb_init("zig_platformer", null, null, 0, 0);
    bb.log("init", "zig_platformer init", .{});
    var app_desc = std.mem.zeroes(c.sapp_desc);
    app_desc.width = 1280;
    app_desc.height = 720;
    app_desc.sample_count = 4;
    app_desc.swap_interval = 0;
    app_desc.gl_force_gles2 = true;
    app_desc.init_cb = init;
    app_desc.frame_cb = update;
    app_desc.cleanup_cb = cleanup;
    app_desc.event_cb = event;
    app_desc.window_title = "Zig Platformer";
    _ = c.sapp_run(&app_desc);
    c.bb_shutdown("", 0);
}
