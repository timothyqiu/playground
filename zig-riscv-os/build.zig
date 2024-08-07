const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
    });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-riscv-os",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // See https://github.com/ziglang/zig/issues/5558
        .code_model = .medium,
    });
    exe.addAssemblyFile(b.path("src/boot.S"));
    exe.setLinkerScript(b.path("src/linker.ld"));
    b.default_step.dependOn(&exe.step);

    const qemu = b.addSystemCommand(&.{
        "qemu-system-riscv64",
        "-machine",
        "virt",
        "-nographic",
        "-bios",
        "none",
        "-kernel",
    });
    qemu.addFileArg(exe.getEmittedBin());
    qemu.step.dependOn(&exe.step);

    const run_step = b.step("run", "Run in QEMU");
    run_step.dependOn(&qemu.step);
}
