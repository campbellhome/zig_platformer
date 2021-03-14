// adapted from https://github.com/warrenm/AHEasing and https://en.wikipedia.org/wiki/Smoothstep

const std = @import("std");

pub fn clamp(t: anytype, min: @TypeOf(t), max: @TypeOf(t)) @TypeOf(t) {
    return if (t <= min) min else (if (t >= max) max else t);
}

pub fn clamp01(t: anytype) @TypeOf(t) {
    return clamp(t, 0, 1);
}

pub fn smoothstep(t: anytype) @TypeOf(t) {
    const p = clamp01(t);
    return p * p * (3 - 2 * p);
}

pub fn smootherstep(t: anytype) @TypeOf(t) {
    const p = clamp01(t);
    return p * p * p * (p * (p * 6 - 15) + 10);
}

pub fn lerp(t: anytype) @TypeOf(t) {
    return clamp01(t);
}

pub fn quadraticEaseIn(t: anytype) @TypeOf(t) {
    const p = clamp01(t);
    return p * p;
}

pub fn quadraticEaseOut(t: anytype) @TypeOf(t) {
    const p = clamp01(t);
    return -(p * (p - 2));
}

pub fn quadraticEaseInOut(t: anytype) @TypeOf(t) {
    const p = clamp01(t);
    if (p < 0.5) {
        return 2 * p * p;
    }
    return (-2 * p * p) + (4 * p) - 1;
}
