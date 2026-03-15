const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Use explicit GNU target with glibc 2.39 to avoid Zig's LLD choking on
    // GCC 15's .sframe relocations (R_X86_64_PC64) in system crt1.o.
    // This makes Zig supply its own CRT start files while still linking
    // against system shared libraries.
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
        .glibc_version = .{ .major = 2, .minor = 39, .patch = 0 },
    });

    const exe = b.addExecutable(.{
        .name = "tsubame",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Add system library/include paths since non-native target skips them
    exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
    exe.root_module.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });

    exe.linkSystemLibrary("gtk+-3.0");
    exe.linkSystemLibrary("webkit2gtk-4.1");
    exe.linkSystemLibrary("sqlite3");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run tsubame");
    run_step.dependOn(&run_cmd.step);
}
