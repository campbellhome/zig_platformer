// adapted from https://blog.hamaluik.ca/posts/swept-aabb-collision-using-minkowski-difference/
// which references https://gist.github.com/hamaluik/e69f96e253a190273bf0 and https://github.com/pgkelley4/line-segments-intersect/blob/master/js/line-segments-intersect.js

const std = @import("std");
const zlm_specializeOn = @import("zlm/zlm-generic.zig").specializeOn;
usingnamespace zlm_specializeOn(f32);

fn vec2_cross(point1: Vec2, point2: Vec2) f32 {
    return point1.x * point2.y - point1.y * point2.x;
}

pub fn intersect_segments(p: Vec2, p2: Vec2, q: Vec2, q2: Vec2) f32 {
    const r = Vec2.sub(p2, p);
    const s = Vec2.sub(q2, q);

    const numerator = vec2_cross(Vec2.sub(q, p), r);
    const denominator = vec2_cross(r, s);

    if (denominator == 0.0) {
        // parallel or colinear
        return 1.0;
    }

    const u = numerator / denominator;
    const t = vec2_cross(Vec2.sub(q, p), s) / denominator;
    if (t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0) {
        return 1.0;
    }

    return t;
}

pub const AABB = struct {
    center: Vec2,
    extents: Vec2,

    pub const SweepResult = struct {
        start: Vec2,
        delta: Vec2,
        pos: Vec2,
        normal: Vec2,
        t: f32,
        valid: bool,
    };

    pub fn min(this: AABB) Vec2 {
        return vec2(this.center.x - this.extents.x, this.center.y - this.extents.y);
    }

    pub fn max(this: AABB) Vec2 {
        return vec2(this.center.x + this.extents.x, this.center.y + this.extents.y);
    }

    pub fn size(this: AABB) Vec2 {
        return vec2(this.extents.x * 2, this.extents.y * 2);
    }

    pub fn minkowski_difference(this: AABB, other: AABB) AABB {
        const top_left = Vec2.sub(this.min(), other.max());
        const new_size = Vec2.scale(Vec2.add(this.size(), other.size()), 0.5);
        const new_center = Vec2.add(top_left, new_size);
        return AABB{ .center = new_center, .extents = new_size };
    }

    pub fn closest_point_on_bounds(this: AABB, Vec2: point) Vec2 {
        const this_min = this.min();
        const this_max = this.max();
        var min_dist = std.math.fabs(point.x - this_min.x);
        var bounds_point = vec2(this_min.x, point.y);
        if (std.math.fabs(this_max.x - point.x) < min_dist) {
            min_dist = std.math.fabs(this_max.x - point.x);
            bounds_point = vec2(this_max.x, point.y);
        }
        if (std.math.fabs(this_max.y - point.y) < min_dist) {
            min_dist = std.math.fabs(this_max.y - point.y);
            bounds_point = vec2(point.x, this_max.y);
        }
        if (std.math.fabs(this_min.y - point.y) < min_dist) {
            min_dist = std.math.fabs(this_min.y - point.y);
            bounds_point = vec2(point.x, this_min.y);
        }
        return bounds_point;
    }

    fn intersect_segment(segment_start: Vec2, segment_end: Vec2, normal: Vec2, current_result: SweepResult) SweepResult {
        if (Vec2.dot(current_result.delta, normal) > 0) return current_result;
        const t = intersect_segments(Vec2.zero, current_result.delta, segment_start, segment_end);
        return if (t < current_result.t) SweepResult{ .start = current_result.start, .delta = current_result.delta, .pos = Vec2.add(current_result.start, Vec2.scale(current_result.delta, t)), .normal = normal, .t = t, .valid = true } else current_result;
    }

    pub fn intersect_ray(this: AABB, initial_result: SweepResult) SweepResult {
        const this_min = this.min();
        const this_max = this.max();
        var result = initial_result;
        result = intersect_segment(this_min, vec2(this_min.x, this_max.y), vec2(-1, 0), result);
        result = intersect_segment(vec2(this_min.x, this_max.y), this_max, vec2(0, 1), result);
        result = intersect_segment(vec2(this_max.x, this_max.y), vec2(this_max.x, this_min.y), vec2(1, 0), result);
        result = intersect_segment(vec2(this_max.x, this_min.y), vec2(this_min.x, this_min.y), vec2(0, -1), result);
        return result;
    }

    pub fn sweep(this: AABB, other: AABB, delta: Vec2) SweepResult {
        const md = other.minkowski_difference(this);
        const md_min = md.min();
        const md_max = md.max();
        if (md_min.x <= 0.0 and md_max.x >= 0.0 and md_min.y <= 0.0 and md_max.y >= 0.0) {
            return SweepResult{ .start = this.center, .delta = delta, .pos = this.center, .normal = Vec2.zero, .t = 0, .valid = true }; // initial collision
        }

        return md.intersect_ray(SweepResult{ .start = this.center, .delta = delta, .pos = Vec2.add(this.center, delta), .normal = Vec2.zero, .t = 1, .valid = false });
    }
};
