const std = @import("std");
const c = @import("c.zig");
const bb = @import("bb.zig");
const debug = @import("debug.zig");
const render = @import("render.zig");
const easing = @import("easing.zig");
const audio = @import("audio.zig");

pub const zlm_specializeOn = @import("zlm/zlm-generic.zig").specializeOn;
usingnamespace zlm_specializeOn(f32);

const AABB = @import("aabb.zig").AABB;
const Room = @import("room.zig").Room;
const Color = @import("color.zig").Color;

pub const Collision = enum {
    solid,
    player,
    kill,
    trigger,
};

pub const Brain = enum {
    none,
    player,
    platform,
    room_switch,
    dash_recharge,
};

pub const Movement = enum {
    none,
    walking,
    jumping,
    falling,
    dashing,
    hanging,
};

pub const PlayerConfig = struct {
    jump_speed: f32 = 6.0,
    jump_min_duration: f32 = 0.1,
    jump_max_duration: f32 = 0.2,
    jump_hang_boost: f32 = 2.0,
    jump_hang_slowdown: f32 = 0.1,
    jump_hang_boost_vel: f32 = 3.0,
    jump_hang_slowdown_vel: f32 = -1.0,
    jump_hang_dt: f32 = 0.9,
    coyote_time: f32 = 0.5,
    coyote_dist: f32 = 0.6,
    falling_accel: f32 = 50,
    falling_max_speed: f32 = 20,
    falling_drag: f32 = 0.7,
    falling_reverse_drag: f32 = 0.5,
    falling_step_height: f32 = 0.5,
    walk_accel: f32 = 50,
    walk_max_speed: f32 = 20,
    walk_drag: f32 = 0.6,
    walk_reverse_drag: f32 = 0.3,
    walk_step_height: f32 = 1,
    dash_speed: f32 = 40,
    dash_dist: f32 = 5,
    dash_end_vert_speed: f32 = 1,
    dash_slowdown: Vec2 = Vec2{ .x = 0.8, .y = 0.5 },
    hang_grab_dist: f32 = 1,
    hang_accel: f32 = 40,
    hang_max_speed_up: f32 = 2,
    hang_max_speed_down: f32 = 5,
    hang_drag: f32 = 0.6,
    hang_reverse_drag: f32 = 0.3,
    dash_any_angle: bool = false,
    visual_offset_blend_time: f32 = 0.04,
};
pub const ObjectConfig = struct {
    gravity: Vec2 = Vec2{ .x = 0, .y = -40 },
    player: PlayerConfig = PlayerConfig{},
    trigger_dash_recharge_time: f32 = 5,
};
var config = ObjectConfig{};

pub const Object = struct {
    const MovementBackup: f32 = 0.001;

    // id
    object_id: Room.ObjectId = undefined,

    // physics
    bounds: AABB,
    accel: Vec2 = Vec2.zero,
    vel: Vec2 = Vec2.zero,
    collision: Collision = Collision.solid,

    // render
    visual_offset: Vec2 = Vec2.zero,
    visual_offset_start: Vec2 = Vec2.zero,
    depth: f32 = render.depth.tile,
    facing_right: bool = false,
    pulse_elapsed: f32 = 0,
    visible: bool = true,

    // movement
    movement: Movement = Movement.none,
    movement_elapsed: f32 = 0,
    coyote_time: f32 = 0,
    coyote_pos: Vec2 = Vec2.zero,
    near_jump_surface_time: f32 = 0,
    jumps_remaining: i32 = 0,
    input_dir: Vec2 = Vec2.zero,
    available_jumps: i32 = 1,
    max_jumps: i32 = 1,
    available_dashes: i32 = 1,
    max_dashes: i32 = 1,
    grab_dir: Vec2 = Vec2.zero,
    base: Room.ObjectId = Room.InvalidObjectId,
    base_offset: Vec2 = Vec2.zero,

    // Brain.platform
    brain: Brain = Brain.none,
    rest_center: Vec2 = Vec2.zero,
    target_offset: Vec2 = Vec2.zero,
    target_center: Vec2 = Vec2.zero,

    // Brain.dash_recharge
    recharge_time: f32 = 0,

    // misc
    target_room: i32 = -1,

    pub fn init_player(self: *Object) void {
        self.depth = render.depth.player;
    }

    pub fn init_platform(self: *Object, target_offset: Vec2) void {
        self.rest_center = self.bounds.center;
        self.target_offset = target_offset;
        self.target_center = Vec2.add(self.bounds.center, self.target_offset);
        self.brain = Brain.platform;
        if (std.math.fabs(target_offset.x) > std.math.fabs(target_offset.y)) {
            self.bounds.extents = Vec2.mul(self.bounds.extents, Vec2{ .x = 3, .y = 1 });
        } else {
            self.bounds.extents = Vec2.mul(self.bounds.extents, Vec2{ .x = 1, .y = 3 });
        }
    }

    fn set_pos(self: *Object, room: Room, pos: Vec2) bool {
        const old = self.bounds.center;
        self.bounds.center = pos;
        const hits = room.sweep_objects(self.*, Vec2.zero);
        const hit = hits.items[0].self;
        if (hit.valid) {
            bb.warning("move", "set_pos: {d} {d} to {d} {d} failed", .{ old.x, old.y, pos.x, pos.y });
            self.bounds.center = old;
            return false;
        }
        return true;
    }

    pub fn snap_to_ground(self: *Object, room: Room, distance: f32) bool {
        const hits = room.sweep_objects(self.*, Vec2{ .x = 0, .y = -distance });
        const hit = hits.items[0].self;
        if (hit.valid) {
            if (self.set_pos(room, Vec2{ .x = hit.pos.x, .y = hit.pos.y + Object.MovementBackup })) {
                self.set_movement(Movement.walking);

                var best_id: Room.ObjectId = Room.InvalidObjectId;
                var best_dist_sq: f32 = std.math.f32_max;
                for (hits.items) |item| {
                    const item_obj = room.get_object(item.other);
                    if (item_obj != null) {
                        const dist_sq = Vec2.length(Vec2.sub(self.bounds.center, item_obj.?.bounds.center));
                        if (best_dist_sq > dist_sq) {
                            best_dist_sq = dist_sq;
                            best_id = item.other;
                        }
                    }
                }
                self.set_base(room, best_id);
                return true;
            }
        }
        return false;
    }

    pub fn snap_to_room(self: *Object, room: Room, delta: Vec2) bool {
        const hits = room.sweep_objects(self.*, delta);
        const hit = hits.items[0].self;
        if (hit.valid) {
            if (self.set_pos(room, Object.get_sweep_pos(hit))) {
                return true;
            }
        }
        return false;
    }

    pub fn add_visual_offset(self: *Object, offset: Vec2) void {
        self.visual_offset = Vec2.add(self.visual_offset, offset);
        self.visual_offset_start = self.visual_offset;
    }

    pub fn set_movement(self: *Object, movement: Movement) void {
        if (self.movement != movement) {
            self.movement = movement;
            self.movement_elapsed = 0;
            self.coyote_time = 0;
            self.coyote_pos = Vec2.zero;
            if (movement == Movement.walking) {
                self.available_jumps = self.max_jumps;
                if (self.available_dashes != self.max_dashes) {
                    self.pulse_elapsed = 0;
                    self.available_dashes = self.max_dashes;
                }
                self.grab_dir = Vec2.zero;
            } else if (movement == Movement.hanging) {
                self.available_jumps = self.max_jumps;
            }
            audio.stop_looped(.running);
            audio.stop_looped(.climb);
            audio.stop_looped(.slide);
        }
    }

    fn set_base(self: *Object, room: Room, base: Room.ObjectId) void {
        self.base = base;
        const base_obj = room.get_object(base);
        self.base_offset = if (base_obj != null) Vec2.sub(self.bounds.center, base_obj.?.bounds.center) else Vec2.zero;
    }

    pub fn sim(self: *Object, room: *Room, dt: f32) void {
        switch (self.brain) {
            .none => {},
            .player => {
                self.sim_player(room, dt);
            },
            .platform => {
                self.sim_platform(room, dt);
            },
            .room_switch => {},
            .dash_recharge => {
                self.sim_dash_recharge(room, dt);
            },
        }
    }

    pub fn sim_platform(self: *Object, room: *Room, dt: f32) void {
        const speed: f32 = 2;
        const remaining = Vec2.sub(self.target_center, self.bounds.center);
        const dir = remaining.normalize();
        const delta = speed * dt;
        const move = Vec2.scale(dir, delta);

        const hits = room.sweep_objects(self.*, move);
        for (hits.items) |item| {
            const item_obj = room.get_object_ptr(item.other);
            if (item_obj != null) {
                if (item_obj.?.collision == Collision.player) {
                    item_obj.?.bounds.center = Vec2.add(item_obj.?.bounds.center, move);
                }
            }
        }

        self.bounds.center = Vec2.add(self.bounds.center, move);
        if (Vec2.length2(remaining) < 0.001 or Vec2.dot(Vec2.sub(self.target_center, self.bounds.center), remaining) < 0) {
            if (self.target_center.x == self.rest_center.x and self.target_center.y == self.rest_center.y) {
                self.target_center = Vec2.add(self.bounds.center, self.target_offset);
            } else {
                self.target_center = self.rest_center;
            }
        }
    }

    fn sim_dash_recharge(self: *Object, room: *Room, dt: f32) void {
        if (self.recharge_time > 0) {
            self.recharge_time -= dt;
            if (self.recharge_time <= 0) {
                self.recharge_time = 0;
            }
        }
    }

    pub fn sim_player(self: *Object, room: *Room, dt: f32) void {
        const VisualOffsetMin: f32 = 0.001;
        if (std.math.fabs(self.visual_offset.x) > VisualOffsetMin or std.math.fabs(self.visual_offset.y) > VisualOffsetMin) {
            const start = self.visual_offset;
            self.visual_offset = Vec2.sub(self.visual_offset, Vec2.scale(self.visual_offset_start, dt / config.player.visual_offset_blend_time));
            if (Vec2.dot(self.visual_offset, start) <= 0) {
                self.visual_offset = Vec2.zero;
                self.visual_offset_start = Vec2.zero;
            }
        } else {
            self.visual_offset = Vec2.zero;
            self.visual_offset_start = Vec2.zero;
        }
        self.pulse_elapsed += dt;

        const base_obj = room.get_object(self.base);
        if (base_obj != null) {
            const base_offset = Vec2.sub(self.bounds.center, base_obj.?.bounds.center);
            const delta = Vec2.sub(self.base_offset, base_offset);
            self.bounds.center = Vec2.add(self.bounds.center, delta);
        }

        self.movement_elapsed += dt;

        var has_input_dir = false;
        self.input_dir = Vec2.zero;
        if (room.input.left_stick_horiz != 0) {
            self.input_dir.x = room.input.left_stick_horiz;
            has_input_dir = true;
        } else if (room.input.up) {
            self.input_dir.y += 1;
            has_input_dir = true;
        } else if (room.input.down) {
            self.input_dir.y -= 1;
            has_input_dir = true;
        }
        if (room.input.left_stick_vert != 0) {
            self.input_dir.y = room.input.left_stick_vert;
            has_input_dir = true;
        } else if (room.input.right) {
            self.input_dir.x += 1;
            has_input_dir = true;
        } else if (room.input.left) {
            self.input_dir.x -= 1;
            has_input_dir = true;
        }

        if (self.coyote_time > 0) {
            self.coyote_time -= dt;
            if (self.coyote_time <= 0 or Vec2.length(Vec2.sub(self.bounds.center, self.coyote_pos)) > config.player.coyote_dist or
                self.input_dir.y < -0.7 or !has_input_dir)
            {
                self.end_coyote_time();
                if (!self.snap_to_ground(room.*, 1)) {
                    self.set_movement(Movement.falling);
                }
            }
        }

        if (self.near_jump_surface(room.*, self.vel) or
            self.near_jump_surface(room.*, self.input_dir) or
            ((self.movement != .jumping or self.movement_elapsed > 0.2) and self.near_jump_surface(room.*, Vec2{ .x = 0, .y = -1 })))
        {
            self.near_jump_surface_time = 0.02;
        } else {
            self.near_jump_surface_time -= dt;
        }
        if (room.input.jump and !room.prev_input.jump) {
            const can_jump = (self.available_jumps > 0 and self.available_jumps < self.max_jumps) or self.movement == .walking or self.movement == .hanging or self.near_jump_surface_time > 0;
            if (can_jump) {
                self.available_jumps -= 1;
                self.set_movement(Movement.jumping);
                self.vel.y = config.player.jump_speed;
                audio.play(.effort);
                self.near_jump_surface_time = 0;
            }
        }

        if (room.input.dash and !room.prev_input.dash and self.available_dashes > 0 and has_input_dir) {
            self.start_dashing(room);
        }

        if (room.input.grab and !room.input.jump and !room.input.dash) {
            self.try_grab(room);
        }

        switch (self.movement) {
            .none => {},
            .walking => {
                self.move_walking(room, dt);
            },
            .jumping => {
                self.move_jumping(room, dt);
            },
            .falling => {
                self.move_falling(room, dt);
            },
            .dashing => {
                self.move_dashing(room, dt);
            },
            .hanging => {
                self.move_hanging(room, dt);
            },
        }

        if (self.grab_dir.x != 0 and self.movement == .hanging) {
            self.facing_right = self.grab_dir.x < 0;
        } else if (self.vel.x != 0) {
            self.facing_right = self.vel.x < 0;
        }

        if (self.movement == .dashing) {
            room.add_player_trail(AABB{ .center = self.get_visual_center(), .extents = self.bounds.extents }, self.get_player_image(), self.facing_right);
        }

        self.touch_triggers(room);

        // if (debug.showing_ui()) {
        //     const hit = room.sweep_objects(self.*, Vec2.zero).items[0].self;

        //     {
        //         var buffer: [1024]u8 = undefined;
        //         const buffer_slice = buffer[0..];
        //         const text = std.fmt.bufPrint(buffer_slice, "movement: {} {}", .{ self.movement, hit }) catch "fmt failed";
        //         _ = c.igTextUnformatted(text.ptr, null);
        //     }
        //     {
        //         var buffer: [1024]u8 = undefined;
        //         const buffer_slice = buffer[0..];
        //         const text = std.fmt.bufPrint(buffer_slice, "vel: {d} {d}", .{ self.vel.x, self.vel.y }) catch "fmt failed";
        //         _ = c.igTextUnformatted(text.ptr, null);
        //     }
        // }
    }

    fn touch_triggers(self: *Object, room: *Room) void {
        const hits = room.sweep_objects_of_types(self.*, Vec2.zero, &[_]Collision{.trigger});
        for (hits.items) |hit| {
            if (hit.self.valid) {
                const other: *Object = room.get_object_ptr(hit.other).?;
                if (other.brain == .dash_recharge and other.recharge_time == 0) {
                    if (self.available_dashes != self.max_dashes) {
                        self.pulse_elapsed = 0;
                        self.available_dashes = self.max_dashes;
                        other.*.recharge_time = config.trigger_dash_recharge_time;
                    }
                }
            }
        }
    }

    fn near_jump_surface(self: Object, room: Room, move: Vec2) bool {
        const hits = room.sweep_objects(self, Vec2.scale(Vec2.normalize(move), 0.5));
        const hit = hits.items[0].self;
        if (hit.valid and hit.normal.y > -0.9) {
            return true;
        } else {
            return false;
        }
    }

    fn get_sweep_pos(hit: AABB.SweepResult) Vec2 {
        if (!hit.valid) return hit.pos;
        const backup_pos = Vec2.sub(hit.pos, Vec2.scale(hit.delta.normalize(), MovementBackup));
        const dot = hit.delta.dot(Vec2.sub(backup_pos, hit.start));
        if (dot <= 0) return hit.start;
        return backup_pos;
    }

    fn move_and_step_up_pos(self: *Object, room: *Room, move: Vec2, step_height: f32) Vec2 {
        const start = self.bounds.center;
        const hits = room.sweep_objects(self.*, move);
        const hit = hits.items[0].self;
        if (hit.t > 0 and hit.t < 1) {
            defer self.bounds.center = start;
            const up_hits = room.sweep_objects(self.*, Vec2{ .x = 0, .y = step_height });
            const up_hit = up_hits.items[0].self;
            if (up_hit.t > 0) {
                self.bounds.center = Object.get_sweep_pos(up_hit);
                const stepped_hits = room.sweep_objects(self.*, move);
                const stepped_hit = stepped_hits.items[0].self;
                if (stepped_hit.t > hit.t) {
                    self.bounds.center = Object.get_sweep_pos(stepped_hit);
                    const down_hits = room.sweep_objects(self.*, Vec2{ .x = 0, .y = -step_height });
                    const down_hit = down_hits.items[0].self;
                    if (down_hit.t > 0 and down_hit.valid) {
                        return Object.get_sweep_pos(down_hit);
                    }
                }
            }
        }
        return Object.get_sweep_pos(hit);
    }

    fn move_and_step_up(self: *Object, room: *Room, move: Vec2, step_height: f32) void {
        const start = self.bounds.center;
        const end = self.move_and_step_up_pos(room, move, step_height);
        if (self.set_pos(room.*, end) and start.y != end.y) {
            self.add_visual_offset(Vec2{ .x = 0, .y = start.y - end.y });
        }
    }

    fn move_walking(self: *Object, room: *Room, dt: f32) void {
        if (self.input_dir.x == 0) {
            self.vel.x *= config.player.walk_drag;
            if (std.math.fabs(self.vel.x) < 0.001) {
                self.vel.x = 0;
            }
            audio.stop_looped(.running);
        } else {
            if ((self.vel.x < 0) != (self.input_dir.x < 0)) {
                self.vel.x *= config.player.walk_reverse_drag;
            }
            self.vel.x += config.player.walk_accel * self.input_dir.x * dt;
            self.vel.x = if (self.vel.x < -config.player.walk_max_speed) -config.player.walk_max_speed else if (self.vel.x > config.player.walk_max_speed) config.player.walk_max_speed else self.vel.x;
            audio.start_looped(.running);
        }

        const move = Vec2.scale(self.vel, dt);
        self.move_and_step_up(room, move, config.player.walk_step_height);
        if (!self.snap_to_ground(room.*, 1)) {
            self.set_base(room.*, self.base);
            if (self.coyote_time == 0) {
                self.start_coyote_time();
            }
        }
    }

    fn start_coyote_time(self: *Object) void {
        self.coyote_time = config.player.coyote_time;
        self.coyote_pos = self.bounds.center;
    }

    fn end_coyote_time(self: *Object) void {
        self.coyote_time = 0;
        self.coyote_pos = Vec2.zero;
    }

    fn move_jumping(self: *Object, room: *Room, dt: f32) void {
        self.set_base(room.*, Room.InvalidObjectId);

        self.vel.y = config.player.jump_speed;
        if (self.movement_elapsed > config.player.jump_min_duration and (!room.input.jump or self.movement_elapsed > config.player.jump_max_duration)) {
            self.set_movement(.falling);
        }
        self.move_falling(room, dt);
    }

    fn move_falling(self: *Object, room: *Room, dt: f32) void {
        self.set_base(room.*, Room.InvalidObjectId);

        if (self.input_dir.x == 0) {
            self.vel.x *= config.player.falling_drag;
        } else {
            if ((self.vel.x < 0) != (self.input_dir.x < 0)) {
                self.vel.x *= config.player.falling_reverse_drag;
            }

            if (std.math.fabs(self.vel.x) < config.player.falling_max_speed) {
                self.vel.x += config.player.falling_accel * self.input_dir.x * dt;
                self.vel.x = if (self.vel.x < -config.player.falling_max_speed) -config.player.falling_max_speed else if (self.vel.x > config.player.falling_max_speed) config.player.falling_max_speed else self.vel.x;
            }
        }

        const descend_modifier: f32 = if (self.vel.y > config.player.jump_hang_slowdown_vel) config.player.jump_hang_slowdown else 1.0;
        const hang_modifier: f32 = if (self.vel.y > config.player.jump_hang_boost_vel) config.player.jump_hang_boost else descend_modifier;
        const dt_modifier: f32 = if (self.vel.y < config.player.jump_hang_boost_vel and self.vel.y > config.player.jump_hang_slowdown_vel) config.player.jump_hang_dt else 1.0;
        self.vel = Vec2.add(self.vel, Vec2.scale(config.gravity, dt * dt_modifier));

        const start = self.bounds.center;
        const orig_move = Vec2.scale(self.vel, dt);
        const move = Vec2{ .x = orig_move.x, .y = orig_move.y * hang_modifier };

        const vert_move = Vec2{ .x = 0, .y = move.y };
        const horiz_move = Vec2{ .x = move.x, .y = 0 };

        self.move_and_step_up(room, horiz_move, config.player.falling_step_height);
        if (std.math.fabs(start.x + horiz_move.x - self.bounds.center.x) > 0.001) {
            self.vel.x = 0;
        }

        const hits = room.sweep_objects(self.*, vert_move);
        const hit = hits.items[0].self;
        _ = self.set_pos(room.*, Object.get_sweep_pos(hit));
        if (hit.normal.y > 0) {
            if (self.vel.y < -10) {
                audio.play(.jump_land_1);
            }
            self.vel.y = 0;
            self.set_movement(Movement.walking);
        } else if (hit.normal.y < 0) {
            self.vel.y = 0;
        }
    }

    fn start_dashing(self: *Object, room: *Room) void {
        self.pulse_elapsed = 0;
        self.available_dashes -= 1;
        self.set_movement(Movement.dashing);
        self.movement_elapsed = 0;
        var dash_dir = Vec2.normalize(self.input_dir);
        if (!config.player.dash_any_angle) {
            var best_dash_dir = dash_dir;
            var best_dot: f32 = -1;
            for ([_]Vec2{ vec2(1, 0), vec2(1, 1), vec2(0, 1), vec2(-1, 1), vec2(-1, 0), vec2(-1, -1), vec2(0, -1), vec2(1, -1) }) |test_dir| {
                const normalized_test_dir = Vec2.normalize(test_dir);
                const dot = Vec2.dot(normalized_test_dir, dash_dir);
                if (best_dot < dot) {
                    best_dot = dot;
                    best_dash_dir = normalized_test_dir;
                }
            }
            dash_dir = best_dash_dir;
        }
        self.vel = Vec2.scale(dash_dir, config.player.dash_speed);
        audio.play(.pop);
    }

    fn move_dashing(self: *Object, room: *Room, dt: f32) void {
        self.set_base(room.*, Room.InvalidObjectId);
        if (dt <= 0) return;
        if (config.player.dash_speed == 0) {
            self.set_movement(Movement.falling);
            return;
        }
        const dash_time = config.player.dash_dist / config.player.dash_speed;
        if (self.movement_elapsed >= dash_time) {
            if (std.math.fabs(self.vel.y) > config.player.dash_end_vert_speed) {
                self.vel = Vec2.mul(self.vel, config.player.dash_slowdown);
            } else {
                self.set_movement(Movement.falling);
                self.move_falling(room, dt);
            }
        }

        const start = self.bounds.center;
        const vert_move = Vec2{ .x = 0, .y = self.vel.y * dt };
        const horiz_move = Vec2{ .x = self.vel.x * dt, .y = 0 };

        self.move_and_step_up(room, horiz_move, config.player.falling_step_height);
        if (std.math.fabs(start.x + horiz_move.x - self.bounds.center.x) > 0.001) {
            self.vel.x = 0;
        }

        const hits = room.sweep_objects(self.*, vert_move);
        const hit = hits.items[0].self;
        _ = self.set_pos(room.*, Object.get_sweep_pos(hit));
        if (hit.valid) {
            self.vel.y = 0;
        }
    }

    fn try_grab(self: *Object, room: *Room) void {
        const grab_dir_x = if (self.vel.x != 0) self.vel.x else self.grab_dir.x;
        const input_dir_x = if (self.input_dir.x != 0) self.input_dir.x else grab_dir_x;
        if (input_dir_x == 0) return;
        const start = self.bounds.center;
        const delta = Vec2{ .x = if (input_dir_x > 0) config.player.hang_grab_dist else -config.player.hang_grab_dist, .y = 0 };
        if (self.snap_to_room(room.*, delta)) {
            if (self.movement != .hanging) {
                audio.play(.grab);
            }
            self.set_movement(Movement.hanging);
            self.grab_dir = Vec2{ .x = input_dir_x, .y = 0 };
            self.add_visual_offset(Vec2.sub(start, self.bounds.center));
        }
    }

    fn move_hanging(self: *Object, room: *Room, dt: f32) void {
        if (dt <= 0) return;
        if (!room.input.grab) {
            self.set_movement(Movement.falling);
            self.move_falling(room, dt);
            return;
        }

        self.vel.x = 0;
        if (self.input_dir.y == 0) {
            self.vel.y *= config.player.hang_drag;
            if (std.math.fabs(self.vel.y) < 0.001) {
                self.vel.y = 0;
            }
            audio.stop_looped(.climb);
            audio.stop_looped(.slide);
        } else {
            if (self.input_dir.y > 0) {
                audio.start_looped(.climb);
            } else {
                audio.start_looped(.slide);
            }
            if ((self.vel.y < 0) != (self.input_dir.y < 0)) {
                self.vel.y *= config.player.hang_reverse_drag;
            }
            self.vel.y += config.player.hang_accel * self.input_dir.y * dt;
            self.vel.y = if (self.vel.y < -config.player.hang_max_speed_down) -config.player.hang_max_speed_down else if (self.vel.y > config.player.hang_max_speed_up) config.player.hang_max_speed_up else self.vel.y;
        }

        const pre_move_center = self.bounds.center;
        const vert_move = Vec2.scale(self.vel, dt);
        const vert_hits = room.sweep_objects(self.*, vert_move);
        const vert_hit = vert_hits.items[0].self;
        const vert_pos = Object.get_sweep_pos(vert_hit);
        _ = self.set_pos(room.*, Object.get_sweep_pos(vert_hit));
        if (vert_hit.valid) {
            self.vel.y = 0;
        }

        const horiz_move = Vec2.scale(self.grab_dir, 0.1);
        const horiz_hits = room.sweep_objects(self.*, horiz_move);
        const horiz_hit = horiz_hits.items[0].self;
        if (horiz_hit.valid) {
            var best_id: Room.ObjectId = Room.InvalidObjectId;
            var best_y: f32 = -std.math.f32_max;
            for (horiz_hits.items) |item| {
                const item_obj = room.get_object(item.other);
                if (item_obj != null) {
                    if (best_y < item_obj.?.bounds.center.y) {
                        best_y = item_obj.?.bounds.center.y;
                        best_id = item.other;
                    }
                }
            }
            self.set_base(room.*, best_id);
        } else {
            self.vel.y = 0;
            self.bounds.center = pre_move_center;
            self.set_base(room.*, self.base);
        }
    }

    pub fn get_visual_center(self: Object) Vec2 {
        return Vec2.add(self.bounds.center, self.visual_offset);
    }

    fn draw_nearby_bounds(self: Object, room: Room, delta: Vec2, color: Color) void {
        const hits = room.sweep_objects(self, delta);
        for (hits.items) |hit| {
            if (hit.self.valid) {
                const other = room.get_object(hit.other);
                if (other != null) {
                    const other_center = other.?.get_visual_center();
                    room.draw_rect_outline(Vec2.sub(other_center, other.?.bounds.extents), Vec2.add(other_center, other.?.bounds.extents), color);
                }
            }
        }
    }

    fn get_player_image(self: Object) render.Images {
        switch (self.movement) {
            .none => {
                return .guy_stand;
            },
            .walking => {
                if (self.vel.x == 0) {
                    return .guy_stand;
                } else {
                    const alt = (@floatToInt(i32, self.movement_elapsed * 4) & 0x1) != 0;
                    return if (alt) .guy_run2 else .guy_run1;
                }
            },
            .jumping => {
                return .guy_jump;
            },
            .falling => {
                return .guy_jump;
            },
            .dashing => {
                return .guy_jump;
            },
            .hanging => {
                if (self.vel.y > 0) {
                    const alt = (@floatToInt(i32, self.movement_elapsed * 4) & 0x1) != 0;
                    return if (alt) .guy_climb2 else .guy_climb1;
                } else {
                    return .guy_hang;
                }
            },
        }
    }

    pub fn draw_player(self: Object, room: Room) void {
        const center = self.get_visual_center();
        const extents = self.bounds.extents;

        const pulse = 1 - easing.quadraticEaseIn(self.pulse_elapsed * 2);
        const primary: f32 = 0.8 + 0.2 * pulse;
        const secondary: f32 = 0.6 - 0.2 * pulse;
        const color = if (self.available_dashes > 0) Color.make(secondary, primary, secondary) else Color.make(primary, secondary, secondary);
        const image = self.get_player_image();
        render.room_image_reversible(room, center, extents, self.depth, color, image, self.facing_right);
    }

    pub fn draw(self: Object, room: Room) void {
        if (!self.visible) return;
        const center = self.get_visual_center();
        const extents = self.bounds.extents;

        switch (self.collision) {
            Collision.solid => {
                render.room_image(room, center, extents, self.depth, Color.white, .tile_gray);
            },
            Collision.kill => {
                room.draw_rect_multicolor(Vec2.sub(center, extents), Vec2.add(center, extents), Color.make(0.8, 0, 0), Color.make(0.8, 0, 0), Color.make(0.6, 0, 0), Color.make(0.7, 0, 0));
            },
            Collision.player => {
                self.draw_player(room);

                if (room.show_nearby) {
                    self.draw_nearby_bounds(room, Vec2{ .x = 0, .y = -config.player.walk_step_height }, Color.make(0, 0.86, 0));
                    self.draw_nearby_bounds(room, Vec2{ .x = -config.player.walk_step_height, .y = 0 }, Color.make(0, 0.86, 0));
                    self.draw_nearby_bounds(room, Vec2{ .x = config.player.walk_step_height, .y = 0 }, Color.make(0, 0.86, 0));
                }

                if (room.show_base) {
                    const base_obj = room.get_object(self.base);
                    if (base_obj != null) {
                        const base_center = base_obj.?.get_visual_center();
                        room.draw_rect_outline(Vec2.sub(base_center, base_obj.?.bounds.extents), Vec2.add(base_center, base_obj.?.bounds.extents), Color.make(0.86, 0, 0.86));
                        room.draw_line(base_center, center, Color.make(0.86, 0, 0.86));
                    }
                }
            },
            Collision.trigger => {
                if (self.brain == .room_switch) {
                    render.room_image(room, center, extents, self.depth, Color.make(0, 0.5, 0.1), .tile_gray);
                } else if (self.brain == .dash_recharge) {
                    if (self.recharge_time == 0) {
                        render.room_image(room, center, extents, self.depth, Color.make(0, 0.1, 0.8), .tile_gray);
                    } else {
                        const pct = self.recharge_time / config.trigger_dash_recharge_time;
                        render.room_image(room, center, extents, self.depth, Color.make(pct * 0.4, 0.1, (1 - pct) * 0.5), .tile_gray);
                    }
                } else {
                    render.room_image(room, center, extents, self.depth, Color.make(0.5, 0.0, 0.5), .tile_gray);
                }
            },
        }

        if (room.show_collision) {
            room.draw_rect_outline(Vec2.sub(self.bounds.center, extents), Vec2.add(self.bounds.center, extents), Color.white);
        }
    }

    // fn draw_debug_ui_type(comptime T: type, obj: *T) void {
    //     const info = @typeInfo(T);
    //     inline for (info.Struct.fields) |field| {
    //         {
    //             var buffer: [1024]u8 = undefined;
    //             const buffer_slice = buffer[0..];
    //             const text = std.fmt.bufPrint(buffer_slice, "{}.{}: {} {}", .{ @typeName(T), field.name, @typeName(field.field_type), field }) catch "fmt failed";
    //             _ = c.igTextUnformatted(text.ptr, null);
    //         }
    //     }
    // }

    pub fn tweak_ui() void {
        debug.f32_slider("gravity", &config.gravity.y, -10.0, 10.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("jump_speed", &config.player.jump_speed, 0.0, 10.0, 0.2, 0.5, "%.2f", 1.0);
        debug.f32_slider("jump_min_duration", &config.player.jump_min_duration, 0.0, 1.0, 0.05, 0.1, "%.1f", 1.0);
        debug.f32_slider("jump_max_duration", &config.player.jump_max_duration, 0.0, 1.0, 0.05, 0.1, "%.1f", 1.0);
        debug.f32_slider("jump_hang_boost", &config.player.jump_hang_boost, 0.0, 10.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("jump_hang_slowdown", &config.player.jump_hang_slowdown, 0.0, 10.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("jump_hang_boost_vel", &config.player.jump_hang_boost_vel, 0.0, 10.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("jump_hang_slowdown_vel", &config.player.jump_hang_slowdown_vel, 0.0, 10.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("jump_hang_dt", &config.player.jump_hang_dt, 0.0, 10.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("coyote_time", &config.player.coyote_time, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("coyote_dist", &config.player.coyote_dist, 0.0, 5.0, 0.1, 0.5, "%.2f", 1.0);
        debug.f32_slider("falling_accel", &config.player.falling_accel, 0.0, 50.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("falling_max_speed", &config.player.falling_max_speed, 0.0, 50.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("falling_drag", &config.player.falling_drag, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("falling_reverse_drag", &config.player.falling_reverse_drag, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("falling_step_height", &config.player.falling_step_height, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("walk_accel", &config.player.walk_accel, 0.0, 50.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("walk_max_speed", &config.player.walk_max_speed, 0.0, 50.0, 0.2, 0.5, "%.1f", 1.0);
        debug.f32_slider("walk_drag", &config.player.walk_drag, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("walk_reverse_drag", &config.player.walk_reverse_drag, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("walk_step_height", &config.player.walk_step_height, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("dash_speed", &config.player.dash_speed, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("dash_dist", &config.player.dash_dist, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("dash_end_vert_speed", &config.player.dash_end_vert_speed, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("dash_slowdown.x", &config.player.dash_slowdown.x, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        debug.f32_slider("dash_slowdown.y", &config.player.dash_slowdown.y, 0.0, 1.0, 0.01, 0.1, "%.2f", 1.0);
        _ = c.igCheckbox("dash_any_angle", &config.player.dash_any_angle);
        debug.f32_slider("visual_offset_blend_time", &config.player.visual_offset_blend_time, 0.0, 0.1, 0.001, 0.01, "%.2f", 1.0);
        // draw_debug_ui_type(ObjectConfig, &config);
        // draw_debug_ui_type(Vec2, &config.gravity);
        // draw_debug_ui_type(PlayerConfig, &config.player);
    }

    pub fn debug_ui() void {
        var buffer: [1024]u8 = undefined;
        const buffer_slice = buffer[0..];
        const text = std.fmt.bufPrint(buffer_slice, "sizeOf(Room): {} sizeof(Object): {}", .{ @sizeOf(Room), @sizeOf(Object) }) catch "fmt failed";
        _ = c.igTextUnformatted(text.ptr, null);
    }
};
