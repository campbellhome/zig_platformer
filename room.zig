const std = @import("std");
const c = @import("c.zig");
const bb = @import("bb.zig");
const debug = @import("debug.zig");
const easing = @import("easing.zig");
const render = @import("render.zig");
const allocators = @import("allocators.zig");
const audio = @import("audio.zig");

pub const zlm_specializeOn = @import("zlm/zlm-generic.zig").specializeOn;
usingnamespace zlm_specializeOn(f32);

const AABB = @import("aabb.zig").AABB;
const Objects = @import("objects.zig");
const Collision = @import("objects.zig").Collision;
const Movement = @import("objects.zig").Movement;
const Object = @import("objects.zig").Object;
const GameInput = @import("game_input.zig").GameInput;
const Color = @import("color.zig").Color;

fn ImVec2(p: Vec2) c.ImVec2 {
    return c.ImVec2{ .x = p.x, .y = p.y };
}

fn fromImVec2(p: c.ImVec2) Vec2 {
    return Vec2{ .x = p.x, .y = p.y };
}

const MaxObjects: u32 = 512;
const MaxPlayerTrails: u32 = 60;
pub const Room = struct {
    pub const DefaultCameraWidth = 40.0;
    pub const DefaultCameraHeight = 22.0;
    const TicksPerSecond: f64 = 60.0;
    const TickTime: f64 = 1.0 / TicksPerSecond;

    pub const InvalidObjectId = ObjectId{ .index = ~@as(usize, 0) };
    pub const ObjectId = struct {
        index: usize,
    };

    pub const SweepResult = struct {
        self: AABB.SweepResult,
        other: ObjectId,
    };

    const PlayerTrail = struct {
        bounds: AABB,
        image: render.Images,
        facing_right: bool,
        elapsed: f32,
    };

    const Camera = struct {
        focus: ObjectId,
        room_pos: Vec2,
    };

    room_id: i32 = 0,
    timescale: f64 = 1,
    accumulated_frame_time: f64 = 0,
    camera: Camera = undefined,
    player_id: ObjectId = undefined,
    num_objects: usize = 0,
    objects: [MaxObjects]Object = undefined,
    num_player_trails: usize = 0,
    playerTrails: [MaxPlayerTrails]PlayerTrail = undefined,
    screen_size: Vec2 = vec2(1, 1),
    prev_input: GameInput = GameInput{},
    input: GameInput = GameInput{},
    rows: f32 = 0,
    cols: f32 = 0,
    show_collision: bool = false,
    show_nearby: bool = false,
    show_base: bool = false,
    partial: bool = false,
    fade: f32 = 1,

    pub fn init(room_id: i32, room_data: anytype) Room {
        var new_room = Room{};
        new_room.room_id = room_id;

        var rows: f32 = 1.0;
        for (room_data) |value| {
            if (value == '\n') {
                rows += 1;
            }
        }

        var row: f32 = rows - 1.0;
        var col: f32 = 0.0;
        var max_cols: f32 = 0.0;
        for (room_data) |value| {
            if (value == '\n') {
                row -= 1;
                col = 0;
            } else {
                var obj = Object{ .bounds = AABB{ .center = vec2(col + 0.5, row + 0.5), .extents = vec2(0.5, 0.5) } };
                if (value == '#') {
                    _ = new_room.add_object(obj);
                } else if (value == '0') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 0;
                    _ = new_room.add_object(obj);
                } else if (value == '1') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 1;
                    _ = new_room.add_object(obj);
                } else if (value == '2') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 2;
                    _ = new_room.add_object(obj);
                } else if (value == '3') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 3;
                    _ = new_room.add_object(obj);
                } else if (value == '4') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 4;
                    _ = new_room.add_object(obj);
                } else if (value == '5') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 5;
                    _ = new_room.add_object(obj);
                } else if (value == '6') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 6;
                    _ = new_room.add_object(obj);
                } else if (value == '7') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 7;
                    _ = new_room.add_object(obj);
                } else if (value == '8') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 8;
                    _ = new_room.add_object(obj);
                } else if (value == '9') {
                    obj.collision = .trigger;
                    obj.brain = .room_switch;
                    obj.target_room = 9;
                    _ = new_room.add_object(obj);
                } else if (value == 'o') {
                    obj.collision = .trigger;
                    obj.brain = .dash_recharge;
                    _ = new_room.add_object(obj);
                } else if (value == '-') {
                    obj.init_platform(Vec2{ .x = 3, .y = 0 });
                    _ = new_room.add_object(obj);
                } else if (value == '|') {
                    obj.init_platform(Vec2{ .x = 0, .y = -3 });
                    _ = new_room.add_object(obj);
                }
                col += 1;
                max_cols = if (max_cols < col) col else max_cols;
            }
        }

        new_room.rows = rows;
        new_room.cols = max_cols;

        // add players last
        row = rows - 1.0;
        col = 0.0;
        for (room_data) |value| {
            if (value == '\n') {
                row -= 1;
                col = 0;
            } else {
                if (value == '@') {
                    var obj = Object{ .bounds = AABB{ .center = vec2(col + 0.5, row + 1), .extents = vec2(0.5 * 0.95, 0.95) }, .collision = Collision.player, .movement = Movement.falling, .brain = Objects.Brain.player };
                    _ = obj.snap_to_ground(new_room, 0.5);
                    obj.init_player();
                    const added = new_room.add_object(obj);
                    if (added != null) {
                        new_room.player_id = added.?.object_id;
                        new_room.init_camera(added.?.object_id);
                    }
                }
                col += 1;
            }
        }

        return new_room;
    }

    pub fn init_camera(self: *Room, focus: ObjectId) void {
        self.camera.focus = focus;
        self.camera.room_pos = self.objects[focus.index].bounds.center;
        self.sim_camera(0);
    }

    pub fn add_object(self: *Room, obj: Object) ?Object {
        if (self.num_objects == MaxObjects)
            return null;
        self.objects[self.num_objects] = obj;
        self.objects[self.num_objects].object_id.index = self.num_objects;
        self.num_objects += 1;
        return self.objects[self.num_objects - 1];
    }

    pub fn get_object(self: *const Room, id: ObjectId) ?Object {
        return if (id.index >= 0 and id.index < self.num_objects) self.objects[id.index] else null;
    }

    pub fn get_object_ptr(self: *Room, id: ObjectId) ?*Object {
        return if (id.index >= 0 and id.index < self.num_objects) &self.objects[id.index] else null;
    }

    pub fn add_player_trail(self: *Room, bounds: AABB, image: render.Images, facing_right: bool) void {
        const player_trail = PlayerTrail{ .bounds = bounds, .image = image, .facing_right = facing_right, .elapsed = 0 };
        if (self.num_player_trails == MaxPlayerTrails) {
            var oldest_index: usize = 0;
            var oldest_elapsed: f32 = 0;
            for (self.playerTrails[0..self.num_player_trails]) |*value, i| {
                if (value.elapsed > oldest_elapsed) {
                    oldest_index = i;
                    oldest_elapsed = value.elapsed;
                }
            }
            self.playerTrails[oldest_index] = player_trail;
        } else {
            self.playerTrails[self.num_player_trails] = player_trail;
            self.num_player_trails += 1;
        }
    }

    pub fn find_portal(self: Room, room_id: i32, up: bool, down: bool, left: bool, right: bool) AABB {
        var min = Vec2{ .x = self.cols, .y = self.rows };
        var max = Vec2.zero;
        for (self.objects[0..self.num_objects]) |value, i| {
            if (value.target_room != room_id) continue;
            if (value.collision != .trigger or value.brain != .room_switch) continue;

            if (up and value.bounds.center.y < self.rows - 1) continue;
            if (down and value.bounds.center.y > 1) continue;
            if (left and value.bounds.center.x > 1) continue;
            if (right and value.bounds.center.x < self.cols - 1) continue;

            const obj_min = value.bounds.min();
            const obj_max = value.bounds.max();
            if (min.x > obj_min.x) {
                min.x = obj_min.x;
            }
            if (max.x < obj_max.x) {
                max.x = obj_max.x;
            }
            if (min.y > obj_min.y) {
                min.y = obj_min.y;
            }
            if (max.y < obj_max.y) {
                max.y = obj_max.y;
            }
        }
        var portal = AABB{ .center = Vec2.scale(Vec2.add(min, max), 0.5), .extents = Vec2.scale(Vec2.sub(max, min), 0.5) };
        return portal;
    }

    fn sim_camera(self: *Room, dt: f32) void {
        const standard_room_size = vec2(DefaultCameraWidth, DefaultCameraHeight);
        const room_size = vec2(self.cols, self.rows);
        const camera_pos = self.objects[self.camera.focus.index].get_visual_center();
        var final_camera_pos = camera_pos;

        const min_camera_pos = Vec2{ .x = DefaultCameraWidth * 0.5, .y = DefaultCameraHeight * 0.5 };
        const max_camera_pos = Vec2{ .x = room_size.x - DefaultCameraWidth * 0.5, .y = room_size.y - DefaultCameraHeight * 0.5 };
        if (final_camera_pos.x < min_camera_pos.x) {
            final_camera_pos.x = min_camera_pos.x;
        } else if (final_camera_pos.x > max_camera_pos.x) {
            final_camera_pos.x = max_camera_pos.x;
        }
        if (final_camera_pos.y < min_camera_pos.y) {
            final_camera_pos.y = min_camera_pos.y;
        } else if (final_camera_pos.y > max_camera_pos.y) {
            final_camera_pos.y = max_camera_pos.y;
        }

        if (room_size.x < standard_room_size.x) {
            final_camera_pos.x = room_size.x * 0.5;
        }
        if (room_size.y < standard_room_size.y) {
            final_camera_pos.y = room_size.y * 0.5;
        }

        self.camera.room_pos = final_camera_pos;
    }

    pub fn screen_scale(self: Room) Vec2 {
        const standard_room_size = vec2(DefaultCameraWidth, DefaultCameraHeight);
        const scale = Vec2.div(self.screen_size, standard_room_size);
        return scale;
    }

    pub fn sweep_objects(self: Room, obj: Object, delta: Vec2) std.ArrayList(SweepResult) {
        var best = SweepResult{ .other = InvalidObjectId, .self = AABB.SweepResult{ .start = obj.bounds.center, .delta = delta, .pos = Vec2.add(obj.bounds.center, delta), .normal = Vec2.zero, .t = 1, .valid = false } };
        var results = std.ArrayList(SweepResult).init(&allocators.frame_arena.allocator);
        results.shrinkRetainingCapacity(0);
        results.append(best) catch unreachable;

        for (self.objects[0..self.num_objects]) |*value, i| {
            if (value.object_id.index == obj.object_id.index) continue;
            if (value.collision == Collision.solid or value.collision == Collision.player) {
                const result = obj.bounds.sweep(value.bounds, delta);
                if (!result.valid) continue;
                if (result.t < best.self.t) {
                    best = SweepResult{ .other = ObjectId{ .index = i }, .self = result };
                    results.shrinkRetainingCapacity(0);
                    results.append(best) catch unreachable;
                } else if (result.t == best.self.t) {
                    results.append(SweepResult{ .other = ObjectId{ .index = i }, .self = result }) catch unreachable;
                }
            }
        }
        return results;
    }

    pub fn sweep_objects_of_types(self: Room, obj: Object, delta: Vec2, types: []const Collision) std.ArrayList(SweepResult) {
        var best = SweepResult{ .other = InvalidObjectId, .self = AABB.SweepResult{ .start = obj.bounds.center, .delta = delta, .pos = Vec2.add(obj.bounds.center, delta), .normal = Vec2.zero, .t = 1, .valid = false } };
        var results = std.ArrayList(SweepResult).init(&allocators.frame_arena.allocator);
        results.shrinkRetainingCapacity(0);
        results.append(best) catch unreachable;

        for (self.objects[0..self.num_objects]) |*value, i| {
            if (value.object_id.index == obj.object_id.index) continue;
            for (types) |collision_type| {
                if (value.collision == collision_type) {
                    const result = obj.bounds.sweep(value.bounds, delta);
                    if (!result.valid) continue;
                    if (result.t < best.self.t) {
                        best = SweepResult{ .other = ObjectId{ .index = i }, .self = result };
                        results.shrinkRetainingCapacity(0);
                        results.append(best) catch unreachable;
                    } else if (result.t == best.self.t) {
                        results.append(SweepResult{ .other = ObjectId{ .index = i }, .self = result }) catch unreachable;
                    }
                    break;
                }
            }
        }
        return results;
    }

    pub fn sim_frame(self: *Room, dt: f64) void {
        const dt32: f32 = @floatCast(f32, dt);
        self.sim_player_trails(dt32);
        for (self.objects[0..self.num_objects]) |*value, i| {
            value.sim(self, dt32);
        }
        self.sim_camera(dt32);
    }

    fn sim_player_trails(self: *Room, dt: f32) void {
        for (self.playerTrails[0..self.num_player_trails]) |*value, i| {
            value.elapsed += dt;
        }
    }

    pub inline fn draw_rect_outline(self: Room, p1: Vec2, p2: Vec2, color: Color) void {
        var draw_list = c.igGetBackgroundDrawList();
        c.ImDrawList_AddRect(draw_list, ImVec2(p1), ImVec2(p2), color.pack(), 0.0, 0, 0);
    }

    pub inline fn draw_rect_filled(self: Room, p1: Vec2, p2: Vec2, color: Color) void {
        var draw_list = c.igGetBackgroundDrawList();
        c.ImDrawList_AddRectFilled(draw_list, ImVec2(p1), ImVec2(p2), color.pack(), 0.0, 0);
    }

    pub inline fn draw_rect_multicolor(self: Room, p1: Vec2, p2: Vec2, color1: Color, color2: Color, color3: Color, color4: Color) void {
        var draw_list = c.igGetBackgroundDrawList();
        c.ImDrawList_AddRectFilledMultiColor(draw_list, ImVec2(p1), ImVec2(p2), color4.pack(), color3.pack(), color2.pack(), color1.pack());
    }

    pub inline fn draw_line(self: Room, p1: Vec2, p2: Vec2, color: Color) void {
        var draw_list = c.igGetBackgroundDrawList();
        c.ImDrawList_AddLine(draw_list, ImVec2(p1), ImVec2(p2), color.pack(), 0.0);
    }

    pub fn draw(self: *Room, dt: f64) void {
        const room_extents = Vec2{ .x = self.cols * 0.5, .y = self.rows * 0.5 };
        const room_bounds = AABB{ .center = room_extents, .extents = room_extents };
        switch (self.room_id) {
            0 => {
                render.room_image(self.*, room_bounds.center, room_bounds.extents, render.depth.bg, Color.make(0, 0.3, 0.4), .white);
            },
            1 => {
                render.room_image(self.*, room_bounds.center, room_bounds.extents, render.depth.bg, Color.make(0, 0.4, 0.3), .white);
            },
            2 => {
                render.room_image(self.*, room_bounds.center, room_bounds.extents, render.depth.bg, Color.make(0, 0.4, 0.4), .white);
            },
            3 => {
                render.room_image(self.*, room_bounds.center, room_bounds.extents, render.depth.bg, Color.make(0, 0.3, 0.3), .white);
            },
            else => {
                render.room_image(self.*, room_bounds.center, room_bounds.extents, render.depth.bg, Color.make(0.3, 0.0, 0.0), .white);
            },
        }

        if (self.fade < 1) {
            render.room_image(self.*, room_bounds.center, room_bounds.extents, render.depth.fade, Color.make_alpha(0, 0, 0, 1 - self.fade), .white);
        }

        var draw_list = c.igGetBackgroundDrawList();
        for (self.objects[0..self.num_objects]) |*value, i| {
            value.draw(self.*);
        }
        self.draw_player_trails();
    }

    fn draw_player_trails(self: Room) void {
        for (self.playerTrails[0..self.num_player_trails]) |*value, i| {
            const t = easing.quadraticEaseInOut(value.elapsed);
            const alpha = 1 - t;
            if (alpha > 0) {
                const color = Color.make_alpha(0.4, 0, 0, alpha);
                render.room_image_reversible(self, value.bounds.center, value.bounds.extents, render.depth.player_trail - t * 0.5, color, value.image, value.facing_right);
            }
        }
    }
};

const RoomData = struct {
    const room_00 = @embedFile("rooms/room_00_data.txt");
    const room_01 = @embedFile("rooms/room_01_data.txt");
    const room_02 = @embedFile("rooms/room_02_data.txt");
    const room_03 = @embedFile("rooms/room_03_data.txt");

    pub fn room_init(index: i32) Room {
        switch (index) {
            0 => {
                return Room.init(0, room_00);
            },
            1 => {
                return Room.init(1, room_01);
            },
            2 => {
                return Room.init(2, room_02);
            },
            3 => {
                return Room.init(3, room_03);
            },
            else => {
                return Room.init(0, room_00);
            },
        }
    }
};

const RoomSwitcherState = enum {
    fading_in,
    active,
    switching_rooms,
    fading_out_for_restart,
};

pub const RoomTicker = struct {
    ticks_per_second: f64 = 60.0,
    tick_time: f64 = 1.0 / 60.0,
    accumulated_frame_time: f64 = 0,

    main: Room = undefined,
    other: Room = undefined,

    partial: Room = Room{},
    using_partial: bool = false,

    zoom: f32 = 1,

    starting_player: Object = undefined,

    state: RoomSwitcherState = .fading_in,

    room_switch_speed: f32 = 1,
    room_switch_percent_raw: f32 = 0,
    room_switch_percent: f32 = 0,
    room_switch_camera_delta: Vec2 = Vec2.zero,
    room_switch_other_offset: Vec2 = Vec2.zero,

    room_switch_player_start: Vec2 = Vec2.zero,
    room_switch_player_offset: Vec2 = Vec2.zero,
    room_switch_room_offset: Vec2 = Vec2.zero,

    fading_in_speed: f32 = 3,
    fading_in_percent_raw: f32 = 0,
    fading_in_percent: f32 = 0,

    fading_out_speed: f32 = 2,
    fading_out_percent_raw: f32 = 0,
    fading_out_percent: f32 = 0,

    pub fn init() RoomTicker {
        var self = RoomTicker{};
        self.main = RoomData.room_init(0);
        self.save_starting_player();
        return self;
    }

    fn save_starting_player(self: *RoomTicker) void {
        self.starting_player = self.main.get_object(self.main.player_id).?;
    }

    fn try_room_switch(self: *RoomTicker) void {
        const player = self.main.get_object(self.main.player_id).?;
        const hits = self.main.sweep_objects_of_types(player, Vec2.zero, &[_]Collision{.trigger});
        for (hits.items) |hit| {
            if (hit.self.valid and self.state == .active) {
                const other = self.main.get_object(hit.other);
                if (other != null) {
                    if (other.?.brain == .room_switch) {
                        self.other = RoomData.room_init(other.?.target_room);
                        self.other.screen_size = self.main.screen_size;
                        self.state = .switching_rooms;
                        self.room_switch_percent_raw = 0;
                        self.room_switch_percent = 0;
                        self.room_switch_player_start = player.bounds.center;

                        const hit_center = other.?.bounds.center;
                        const up = hit_center.y > self.main.rows - 1;
                        const down = hit_center.y < 1;
                        const left = hit_center.x < 1;
                        const right = hit_center.x > self.main.cols - 1;
                        const horiz = left or right;
                        const vert = up or down;
                        const main_portal = self.main.find_portal(self.other.room_id, up, down, left, right);
                        const other_portal = self.other.find_portal(self.main.room_id, down, up, right, left);
                        bb.display("room_switch", "{} --> {}", .{ self.main.room_id, self.other.room_id });

                        const zoom = self.zoom;
                        const DefaultCameraWidth = Room.DefaultCameraWidth;
                        const DefaultCameraHeight = Room.DefaultCameraHeight;
                        const main_room_size = vec2(self.main.cols, self.main.rows);
                        const main_min_camera_pos = Vec2{ .x = DefaultCameraWidth * 0.5, .y = DefaultCameraHeight * 0.5 };
                        const main_max_camera_pos = Vec2{ .x = main_room_size.x - DefaultCameraWidth * 0.5, .y = main_room_size.y - DefaultCameraHeight * 0.5 };
                        bb.log("room_switch", "size: {} portal: {} camera_min: {} camera_max: {}", .{ main_room_size, main_portal, main_min_camera_pos, main_max_camera_pos });

                        const other_room_size = vec2(self.other.cols, self.other.rows);
                        const other_min_camera_pos = Vec2{ .x = DefaultCameraWidth * 0.5, .y = DefaultCameraHeight * 0.5 };
                        const other_max_camera_pos = Vec2{ .x = other_room_size.x - DefaultCameraWidth * 0.5, .y = other_room_size.y - DefaultCameraHeight * 0.5 };
                        bb.log("room_switch", "size: {} portal: {} camera_min: {} camera_max: {}", .{ other_room_size, other_portal, other_min_camera_pos, other_max_camera_pos });

                        const main_screen_scale = self.main.screen_scale();
                        bb.log("room_switch", "main_screen_scale: {}", .{main_screen_scale});

                        const flip: f32 = if (left or down) -1 else 1;
                        const room_switch_offset_blend: Vec2 = Vec2{ .x = if (horiz) -flip * self.main.screen_size.x else 0, .y = if (vert) flip * self.main.screen_size.y else 0 };
                        bb.log("room_switch", "room_switch_offset_blend: {}", .{room_switch_offset_blend});

                        self.room_switch_player_offset = Vec2{ .x = if (horiz) flip * 3.0 else 0, .y = if (vert) if (down) flip * 4.0 else 5.0 else 0 };
                        bb.log("room_switch", "room_switch_player_offset: {}", .{self.room_switch_player_offset});

                        self.room_switch_room_offset = vec2(other_portal.center.x - main_portal.center.x - if (horiz) flip else 0, other_portal.center.y - main_portal.center.y - if (vert) flip else 0);
                        bb.log("room_switch", "room_switch_room_offset: {}", .{self.room_switch_room_offset});

                        const portal_room_delta = Vec2{ .x = if (horiz) 0 else other_portal.center.x - main_portal.center.x, .y = if (vert) 0 else other_portal.center.y - main_portal.center.y };
                        bb.log("room_switch", "portal_room_delta: {}", .{portal_room_delta});

                        const room_switch_portal_offset = Vec2.scale(Vec2.mul(portal_room_delta, main_screen_scale), zoom);
                        bb.log("room_switch", "room_switch_portal_offset: {}", .{room_switch_portal_offset});

                        self.room_switch_camera_delta = Vec2.add(room_switch_offset_blend, room_switch_portal_offset);
                        bb.display("room_switch", "room_switch_camera_delta: {}", .{self.room_switch_camera_delta});

                        if (horiz) {
                            self.room_switch_other_offset = Vec2{ .x = (if (left) -other_room_size.x else main_room_size.x) - portal_room_delta.x, .y = -portal_room_delta.y };
                        } else {
                            self.room_switch_other_offset = Vec2{ .x = -portal_room_delta.x, .y = (if (down) -other_room_size.y else main_room_size.y) - portal_room_delta.y };
                        }
                        bb.display("room_switch", "room_switch_other_offset: {}", .{self.room_switch_other_offset});

                        var other_player = self.other.get_object_ptr(self.other.player_id).?;
                        const old_bounds = other_player.*.bounds.center;
                        other_player.*.bounds.center = Vec2.add(player.bounds.center, self.room_switch_room_offset);
                        self.other.camera.room_pos = other_player.*.bounds.center;
                        self.other.sim_camera(0);
                        other_player.*.bounds.center = old_bounds;

                        const camera_screen_delta = Vec2.sub(self.other.camera.room_pos, self.main.camera.room_pos);
                        bb.log("room_switch", "camera_screen_delta: {}", .{camera_screen_delta});

                        self.room_switch_camera_delta = Vec2.add(self.room_switch_other_offset, camera_screen_delta);
                        bb.display("room_switch", "room_switch_camera_delta: {}", .{self.room_switch_camera_delta});

                        audio.play(.room_change);
                    }
                }
            }
        }
    }

    pub fn sim(self: *RoomTicker, dt: f64, new_input: GameInput) void {
        if (debug.debug_ui()) {
            Object.debug_ui();
        }
        if (debug.tweak_ui()) {
            if (c.igSmallButton("25 FPS")) {
                self.ticks_per_second = 25.0;
                self.tick_time = 1.0 / self.ticks_per_second;
            }
            c.igSameLine(0, 10);
            if (c.igSmallButton("50 FPS")) {
                self.ticks_per_second = 50.0;
                self.tick_time = 1.0 / self.ticks_per_second;
            }
            c.igSameLine(0, 10);
            if (c.igSmallButton("60 FPS")) {
                self.ticks_per_second = 60.0;
                self.tick_time = 1.0 / self.ticks_per_second;
            }
            c.igSameLine(0, 10);
            if (c.igSmallButton("100 FPS")) {
                self.ticks_per_second = 100.0;
                self.tick_time = 1.0 / self.ticks_per_second;
            }

            Object.tweak_ui();
        }
        if (debug.controls_ui()) {
            new_input.draw_controls_ui();
        }

        self.main.screen_size = Vec2{ .x = Room.DefaultCameraWidth, .y = Room.DefaultCameraHeight };
        self.other.screen_size = self.main.screen_size;

        if (self.state == .active) {
            if (new_input.quick_restart and !self.main.input.quick_restart) {
                self.state = .fading_out_for_restart;
                audio.play(.room_change);
            }
        }

        const dt32: f32 = @floatCast(f32, dt);
        if (self.state == .switching_rooms) {
            self.room_switch_percent_raw += dt32 * @floatCast(f32, self.main.timescale) * self.room_switch_speed;
            self.room_switch_percent = easing.quadraticEaseInOut(self.room_switch_percent_raw);
            self.other.timescale = self.main.timescale;
            self.using_partial = false;

            const main_player_offset = Vec2.scale(self.room_switch_player_offset, self.room_switch_percent);
            var main = if (self.using_partial) self.partial else self.main;
            var main_player = main.get_object_ptr(main.player_id).?;
            self.main.objects[main_player.object_id.index].bounds.center = Vec2.add(self.room_switch_player_start, main_player_offset);
            self.main.objects[main_player.object_id.index].visible = false;
            var other_player = self.other.get_object_ptr(self.other.player_id).?;
            const other_player_id = other_player.object_id;
            other_player.* = main_player.*;
            other_player.*.object_id = other_player_id;
            other_player.*.base = Room.InvalidObjectId;
            other_player.*.base_offset = Vec2.zero;
            other_player.*.vel = Vec2.zero;
            other_player.*.accel = Vec2.zero;
            other_player.*.set_movement(.falling);
            other_player.*.bounds.center = Vec2.add(main_player.bounds.center, self.room_switch_room_offset);
            other_player.*.visible = true;
            bb.verbose("room_switch_player", "player: {} --> {}", .{ main_player.bounds.center, other_player.*.bounds.center });

            if (self.room_switch_percent >= 1) {
                self.main = self.other;
                self.other = undefined;
                self.state = .active;
                self.room_switch_percent_raw = 0;
                self.main.fade = 1;
                self.save_starting_player();
            }
        } else if (self.state == .fading_in) {
            self.fading_in_percent_raw += dt32 * @floatCast(f32, self.main.timescale) * self.fading_in_speed;
            self.fading_in_percent = easing.quadraticEaseInOut(self.fading_in_percent_raw);
            self.using_partial = false;
            self.main.fade = self.fading_in_percent;
            if (self.fading_in_percent >= 1) {
                self.state = .active;
                self.main.fade = 1;
                self.fading_in_percent_raw = 0;
            }
        } else if (self.state == .fading_out_for_restart) {
            self.fading_out_percent_raw += dt32 * @floatCast(f32, self.main.timescale) * self.fading_out_speed;
            self.fading_out_percent = easing.quadraticEaseInOut(self.fading_out_percent_raw);
            self.using_partial = false;
            self.main.fade = 1 - self.fading_out_percent;
            if (self.fading_out_percent >= 1) {
                self.main = RoomData.room_init(self.main.room_id);
                self.main.objects[self.starting_player.object_id.index] = self.starting_player;
                self.state = .fading_in;
                self.main.fade = 0;
                self.fading_out_percent_raw = 0;
            }
        }

        var game_ticks: u32 = 0;
        if (self.state == .active) {
            if (self.main.timescale > 0) {
                const MaxMilliseconds: f64 = 100;
                self.accumulated_frame_time += if (dt > MaxMilliseconds) MaxMilliseconds else dt;
                const scaled_tick_time = self.tick_time / self.main.timescale;
                while (self.accumulated_frame_time >= scaled_tick_time * 0.5) {
                    self.main.prev_input = self.main.input;
                    self.main.input = new_input;
                    self.accumulated_frame_time -= scaled_tick_time;
                    self.main.sim_frame(self.tick_time);
                    game_ticks += 1;
                }

                self.try_room_switch();

                if (self.accumulated_frame_time > 0.01) {
                    self.using_partial = true;
                    audio.ignore(true);
                    self.partial = self.main;
                    self.partial.partial = true;
                    self.partial.sim_frame(self.accumulated_frame_time * self.main.timescale);
                    audio.ignore(false);
                } else {
                    self.using_partial = false;
                }
            }
        }

        if (debug.debug_ui()) {
            var buffer: [1024]u8 = undefined;
            const buffer_slice = buffer[0..];
            const text = std.fmt.bufPrint(buffer_slice, "game_ticks: {} using_partial: {}", .{ game_ticks, self.using_partial }) catch "fmt failed";
            _ = c.igTextUnformatted(text.ptr, null);
            if (self.using_partial) {
                _ = c.igTextUnformatted("PARTIAL!", null);
            }
        }

        if (debug.tweak_ui()) {
            _ = c.igCheckbox("show_collision", &self.main.show_collision);
            _ = c.igSameLine(0, 10);
            _ = c.igCheckbox("show_nearby", &self.main.show_nearby);
            _ = c.igSameLine(0, 10);
            _ = c.igCheckbox("show_base", &self.main.show_base);
            debug.f64_slider("timescale", &self.main.timescale, 0.0, 10.0, 0.1, 0.5, "%.2f", 1.0);
            debug.f32_slider("zoom", &self.zoom, 0.0, 10.0, 0.1, 0.5, "%.2f", 1.0);
            debug.f32_slider("room_switch_speed", &self.room_switch_speed, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
            debug.f32_slider("room_switch_percent_raw", &self.room_switch_percent_raw, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
            debug.f32_slider("fade", &self.main.fade, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        }
    }

    pub fn draw(self: *RoomTicker, dt: f64) void {
        var main = if (self.using_partial) self.partial else self.main;
        if (self.state == .switching_rooms) {
            const main_offset = Vec2.scale(self.room_switch_camera_delta, self.room_switch_percent);
            const main_camera_pos = Vec2.add(main.camera.room_pos, main_offset);

            const main_fade_start = 0.6;
            if (self.room_switch_percent > main_fade_start) {
                const fade_pct = (self.room_switch_percent - main_fade_start) / (1 - main_fade_start);
                main.fade = 1 - fade_pct;
            } else {
                main.fade = 1;
            }
            render.set_room_dimensions(main_camera_pos, self.zoom);
            main.draw(dt);

            const other_fade_start = 0.1;
            const other_fade_end = 0.4;
            if (self.room_switch_percent > other_fade_start) {
                if (self.room_switch_percent < other_fade_end) {
                    const fade_pct = (self.room_switch_percent - other_fade_start) / (other_fade_end - other_fade_start);
                    self.other.fade = fade_pct;
                } else {
                    self.other.fade = 1;
                }
            } else {
                self.other.fade = 0;
            }
            render.set_room_dimensions(Vec2.sub(main_camera_pos, self.room_switch_other_offset), self.zoom);
            self.other.draw(dt);
        } else {
            render.set_room_dimensions(main.camera.room_pos, self.zoom);
            main.draw(dt);
        }
    }
};
