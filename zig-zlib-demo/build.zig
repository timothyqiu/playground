const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-zlib-demo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    b.installArtifact(exe);

    if (b.systemIntegrationOption("zlib", .{})) {
        exe.linkSystemLibrary("zlib");
    } else if (b.lazyDependency("zlib", .{})) |zlib_dep| {
        const lib = b.addStaticLibrary(.{
            .name = "z",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        lib.installHeader(zlib_dep.path("zlib.h"), "zlib.h");
        lib.installHeader(zlib_dep.path("zconf.h"), "zconf.h");
        lib.addCSourceFiles(.{
            .root = zlib_dep.path("."),
            .files = zlib_files,
            .flags = &.{
                "-std=c89",
            },
        });
        exe.linkLibrary(lib);
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

const zlib_files = &.{
    "adler32.c",
    "compress.c",
    "crc32.c",
    "deflate.c",
    "gzclose.c",
    "gzlib.c",
    "gzread.c",
    "gzwrite.c",
    "inflate.c",
    "infback.c",
    "inftrees.c",
    "inffast.c",
    "trees.c",
    "uncompr.c",
    "zutil.c",
};
