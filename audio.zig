const std = @import("std");
const c = @import("c.zig");
const bb = @import("bb.zig");

pub const Sounds = enum {
    dash,
    effort,
    jump_land_1,
    jump_land_2,
    jump_land_3,
    running,
    slide,
    room_change,
    climb,
    grab,
    pop,
};

const SoundData = struct {
    const dash = @embedFile("data/audio/dash.wav");
    const effort = @embedFile("data/audio/effort.wav");
    const jump_land_1 = @embedFile("data/audio/jump_land_1.wav");
    const jump_land_2 = @embedFile("data/audio/jump_land_2.wav");
    const jump_land_3 = @embedFile("data/audio/jump_land_3.wav");
    const running = @embedFile("data/audio/running.wav");
    const slide = @embedFile("data/audio/slide.wav");
    const room_change = @embedFile("data/audio/room_change.wav");
    const climb = @embedFile("data/audio/climb.wav");
    const grab = @embedFile("data/audio/grab.wav");
    const pop = @embedFile("data/audio/pop.wav");
};

var soloud: *c.Soloud = undefined;
var speech: *c.Speech = undefined;

var wavs: [@typeInfo(Sounds).Enum.fields.len]*c.Wav = undefined;
var handles: [@typeInfo(Sounds).Enum.fields.len]c_uint = undefined;

var ignore_requests: bool = false;
pub fn ignore(val: bool) void {
    ignore_requests = val;
}

pub fn play(sound: Sounds) void {
    if (!ignore_requests) {
        bb.log("audio", "play {}", .{sound});
        _ = c.Soloud_play(soloud, wavs[@enumToInt(sound)]);
    }
}

pub fn play_handle(sound: Sounds) c_uint {
    if (ignore_requests) {
        return 0;
    } else {
        bb.log("audio", "play_handle {}", .{sound});
        return c.Soloud_play(soloud, wavs[@enumToInt(sound)]);
    }
}

pub fn start_looped(sound: Sounds) void {
    if (ignore_requests) return;

    const index: usize = @enumToInt(sound);
    if (handles[index] == 0) {
        bb.log("audio", "start_looped {}", .{sound});
        handles[index] = play_handle(sound);
        _ = c.Soloud_setLooping(soloud, handles[index], 1);
    }
}

pub fn stop_looped(sound: Sounds) void {
    if (ignore_requests) return;

    const index: usize = @enumToInt(sound);
    if (handles[index] != 0) {
        bb.log("audio", "stop_looped {}", .{sound});
        c.Soloud_fadeVolume(soloud, handles[index], 0, 0.2);
        c.Soloud_setAutoStop(soloud, handles[index], 1);
        handles[index] = 0;
    }
}

pub fn init() void {
    soloud = c.Soloud_create();
    speech = c.Speech_create();

    _ = c.Soloud_initEx(soloud, @enumToInt(c.SOLOUD_ENUMS.SOLOUD_AUTO), @enumToInt(c.SOLOUD_ENUMS.SOLOUD_AUTO), @enumToInt(c.SOLOUD_ENUMS.SOLOUD_AUTO), @enumToInt(c.SOLOUD_ENUMS.SOLOUD_AUTO), @enumToInt(c.SOLOUD_ENUMS.SOLOUD_AUTO));
    //c.Soloud_setGlobalVolume(soloud, 4);

    inline for (@typeInfo(Sounds).Enum.fields) |field, index| {
        handles[index] = 0;
        wavs[index] = c.Wav_create();
        const data = @field(SoundData, field.name);
        const ret = c.Wav_loadMemEx(wavs[index], data, data.len, 0, 0);
        bb.log("audio_init", "[{}] ret:{} size:{} name:{}", .{ index, ret, data.len, field.name });
    }
}

pub fn shutdown() void {
    c.Soloud_deinit(soloud);
    c.Speech_destroy(speech);
    c.Soloud_destroy(soloud);
}

pub fn update(dt: f64) void {}
