const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glslc_step = b.step("glslc", "Compile shaders");
    const shaders_dir = "assets/shaders/";
    const shaders = .{
        .{ "shader.frag", "frag.spv" },
        .{ "shader.vert", "vert.spv" },
    };
    inline for (shaders) |shader| {
        const cmd = b.addSystemCommand(&.{
            "glslc",
            shaders_dir ++ shader[0],
            "-o",
            shaders_dir ++ shader[1],
        });
        glslc_step.dependOn(&cmd.step);
    }

    const exe = b.addExecutable(.{
        .name = "zig-vk-galaxy",
        .root_source_file = .{ .path = "src/main.zig" },
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });
    exe.linkSystemLibrary2("glfw", .{});
    exe.linkSystemLibrary2("vulkan", .{});
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    run_step.dependOn(glslc_step);
}
