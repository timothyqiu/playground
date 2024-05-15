const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const miniaudio_dir = prepareMiniaudio(b).dirname();

    const exe = b.addExecutable(.{
        .name = "zig-opengl",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.addIncludePath(b.path("thirdparty/glad/include"));
    exe.addCSourceFile(.{ .file = b.path("thirdparty/glad/src/glad.c") });
    exe.addIncludePath(b.path("thirdparty/stb"));
    exe.addCSourceFile(.{ .file = b.path("src/stb_image_impl.c") });
    exe.addIncludePath(miniaudio_dir);
    exe.addCSourceFile(.{ .file = b.path("src/miniaudio_impl.c") });
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("libavcodec");
    exe.linkSystemLibrary("libavformat");
    exe.linkSystemLibrary("libavutil");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const audio_test = b.addExecutable(.{
        .name = "audio-test",
        .root_source_file = b.path("src/audio_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    audio_test.addIncludePath(miniaudio_dir);
    audio_test.addCSourceFile(.{ .file = b.path("src/miniaudio_impl.c") });
    audio_test.linkLibC();

    b.installArtifact(audio_test);
    const build_audio_step = b.step("audio", "Build and run audio test");
    build_audio_step.dependOn(&b.addRunArtifact(audio_test).step);
}

fn prepareMiniaudio(b: *std.Build) std.Build.LazyPath {
    const tool_run = b.addSystemCommand(&.{"patch"});
    tool_run.addFileArg(b.path("thirdparty/miniaudio/miniaudio.h"));
    tool_run.addArg("-o");
    const ret = tool_run.addOutputFileArg("miniaudio.h");
    tool_run.addFileArg(b.path("thirdparty/miniaudio/zig-18247.patch"));
    b.getInstallStep().dependOn(&tool_run.step);
    return ret;
}
