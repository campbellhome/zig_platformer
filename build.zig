const std = @import("std");
const builtin = @import("builtin");

const is_windows = std.Target.current.os.tag == .windows;
const is_macos = std.Target.current.os.tag == .macos;

pub fn build(b: *std.build.Builder) anyerror!void {
    b.release_mode = builtin.Mode.Debug;
    const mode = b.standardReleaseOptions();

    const mainFile = "main.zig";
    var exe = b.addExecutable("program", mainFile);
    exe.addIncludeDir(".");
    exe.addIncludeDir("bbclient/include");
    exe.setBuildMode(mode);

    exe.addIncludeDir("soloud/include");
    exe.linkSystemLibrary("./soloud/lib/soloud_static_x64");

    const cFlags = if (is_macos) [_][]const u8{ "-std=c99", "-ObjC", "-fobjc-arc" } else [_][]const u8{"-std=c99"};
    exe.addCSourceFile("compile_sokol.c", &cFlags);
    exe.addCSourceFile("compile_stb.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_array.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_assert.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_connection.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_criticalsection.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_discovery_client.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_discovery_packet.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_discovery_server.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_file.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_log.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_packet.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_serialize.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_socket_errors.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_sockets.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_string.c", &cFlags);
    exe.addCSourceFile("bbclient/src/bb_time.c", &cFlags);

    const cpp_args = [_][]const u8{"-Wno-return-type-c-linkage"};
    exe.addCSourceFile("cimgui/imgui/imgui.cpp", &cpp_args);
    exe.addCSourceFile("cimgui/imgui/imgui_demo.cpp", &cpp_args);
    exe.addCSourceFile("cimgui/imgui/imgui_draw.cpp", &cpp_args);
    exe.addCSourceFile("cimgui/imgui/imgui_widgets.cpp", &cpp_args);
    exe.addCSourceFile("cimgui/cimgui.cpp", &cpp_args);

    exe.addCSourceFile("soloud/src/c_api/soloud_c.cpp", &cpp_args);

    exe.linkLibC();

    if (is_windows) {
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("gdi32");
    } else if (is_macos) {
        const frameworks_dir = try macos_frameworks_dir(b);
        exe.addFrameworkDir(frameworks_dir);
        exe.linkFramework("Foundation");
        exe.linkFramework("Cocoa");
        exe.linkFramework("Quartz");
        exe.linkFramework("QuartzCore");
        exe.linkFramework("Metal");
        exe.linkFramework("MetalKit");
        exe.linkFramework("OpenGL");
        exe.linkFramework("Audiotoolbox");
        exe.linkFramework("CoreAudio");
        exe.linkSystemLibrary("c++");
        exe.enableSystemLinkerHack();
    } else {
        // Not tested
        @panic("OS not supported. Try removing panic in build.zig if you want to test this");
        exe.linkSystemLibrary("GL");
        exe.linkSystemLibrary("GLEW");
    }

    const run_cmd = exe.run();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}

// helper function to get SDK path on Mac sourced from: https://github.com/floooh/sokol-zig
fn macos_frameworks_dir(b: *std.build.Builder) ![]u8 {
    var str = try b.exec(&[_][]const u8{ "xcrun", "--show-sdk-path" });
    const strip_newline = std.mem.lastIndexOf(u8, str, "\n");
    if (strip_newline) |index| {
        str = str[0..index];
    }
    const frameworks_dir = try std.mem.concat(b.allocator, u8, &[_][]const u8{ str, "/System/Library/Frameworks" });
    return frameworks_dir;
}
