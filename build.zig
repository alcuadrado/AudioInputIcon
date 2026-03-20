const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const sysroot_opt = b.option([]const u8, "sysroot", "Path to macOS SDK");

    // Main app
    const exe = b.addExecutable(.{
        .name = "AudioInputIcon",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    addMacOSPaths(exe, sysroot_opt);
    linkFrameworks(exe);
    b.installArtifact(exe);

    // Icon generator tool
    const icongen = b.addExecutable(.{
        .name = "IconGen",
        .root_source_file = b.path("src/icongen.zig"),
        .target = target,
        .optimize = optimize,
    });
    addMacOSPaths(icongen, sysroot_opt);
    linkFrameworks(icongen);
    b.installArtifact(icongen);
}

fn addMacOSPaths(exe: *std.Build.Step.Compile, sysroot_opt: ?[]const u8) void {
    if (sysroot_opt) |sysroot| {
        const b = exe.step.owner;
        exe.addSystemFrameworkPath(.{ .cwd_relative = b.fmt("{s}/System/Library/Frameworks", .{sysroot}) });
        exe.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/usr/include", .{sysroot}) });
        exe.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/usr/lib", .{sysroot}) });
    }
}

fn linkFrameworks(exe: *std.Build.Step.Compile) void {
    exe.linkFramework("CoreAudio");
    exe.linkFramework("AppKit");
    exe.linkFramework("Foundation");
    exe.linkFramework("ServiceManagement");
    exe.linkFramework("CoreFoundation");
    exe.linkLibC();
}
