const std = @import("std");
const linux = @import("src/linux.zig");
const windows = @import("src/windows.zig");
const macos = @import("src/macos.zig");
const build_zon = @import("build.zig.zon");

const assert = std.debug.assert;

pub const sources = @import("src/sdl.zon");

pub const flags = &.{
    "-fno-strict-aliasing",
    "-fvisibility=hidden",
};

pub fn build(b: *std.Build) !void {
    // Get the upstream source and build options
    const upstream = b.dependency("sdl", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const default_target_config = b.option(
        bool,
        "default_target_config",
        \\provides a default `SDL_build_config.h` and dependencies for the current target, defaults
        \\to true
        ,
    ) orelse true;

    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        \\whether to build a static or dynamic library, defaults to static
        ,
    ) orelse .static;

    // Get the so version. This is the same as the SDL version, but the major version is elided
    // since it's baked into the name. This mirrors the official build process.
    var sdl_so_version = comptime std.SemanticVersion.parse(build_zon.dependencies.sdl.version) catch unreachable;
    assert(sdl_so_version.major == 3);
    sdl_so_version.major = 0;

    // Create the library
    const lib = b.addLibrary(.{
        .name = "SDL3",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
        .version = sdl_so_version,
    });
    switch (linkage) {
        .dynamic => {
            lib.root_module.addCMacro("DLL_EXPORT", "1");
            lib.setVersionScript(upstream.path("src/dynapi/SDL_dynapi.sym"));
        },
        .static => lib.root_module.addCMacro("SDL_STATIC_LIB", "1"),
    }
    lib.root_module.addCMacro("SDL_VENDOR_INFO", std.fmt.comptimePrint("\"{s} {s} (SDL {s})\"", .{
        "https://github.com/allyourcodebase/SDL3",
        build_zon.version,
        build_zon.dependencies.sdl.version,
    }));
    lib.installHeadersDirectory(upstream.path("include/SDL3"), "SDL3", .{});
    b.installArtifact(lib);

    // Set the include path
    lib.root_module.addIncludePath(upstream.path("include"));
    lib.root_module.addIncludePath(upstream.path("src"));

    // Compile the generic sources
    lib.root_module.addCSourceFiles(.{
        .files = &sources.generic,
        .root = upstream.path("src"),
        .flags = flags,
    });

    if (default_target_config) {
        const build_config_h = b.addConfigHeader(.{
            .style = .{ .cmake = upstream.path("include/build_config/SDL_build_config.h.cmake") },
            .include_path = "SDL_build_config.h",
        }, .{
            // Don't allow including the default config
            .USING_GENERATED_CONFIG_H = true,

            // Generic audio drivers
            .SDL_AUDIO_DRIVER_DUMMY = true,
            .SDL_AUDIO_DRIVER_DISK = true,

            // Generic video drivers
            .SDL_VIDEO_DRIVER_DUMMY = true,
            .SDL_VIDEO_DRIVER_OFFSCREEN = true,

            // Set the assert level, this logic mirrors the default SDL options with release
            // safe added.
            // https://wiki.libsdl.org/SDL3/SDL_ASSERT_LEVEL
            .SDL_DEFAULT_ASSERT_LEVEL_CONFIGURED = true,
            .SDL_DEFAULT_ASSERT_LEVEL = switch (optimize) {
                .Debug, .ReleaseSafe => @as(i64, 2),
                .ReleaseSmall, .ReleaseFast => @as(i64, 1),
            },
        });
        lib.root_module.addConfigHeader(build_config_h);

        // Configure the build for the target platform
        switch (target.result.os.tag) {
            .linux => linux.build(b, target.result, lib, build_config_h),
            .windows => windows.build(b, target.result, lib, build_config_h),
            .macos => macos.build(b, target.result, lib, build_config_h),
            else => @panic("target has no default config"),
        }
    }

    // Add the Wayland scanner step
    linux.addWaylandScannerStep(b);

    // Translate the C header for the example
    const sdl3_h = b.addTranslateC(.{
        .root_source_file = b.path("src/sdl3.h"),
        .target = target,
        .optimize = optimize,
    });
    sdl3_h.addSystemIncludePath(lib.getEmittedIncludeTree());

    // Add the example
    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.linkLibrary(lib);
    example.root_module.addImport("sdl3_h", sdl3_h.createModule());

    const build_example_step = b.step("example", "Build the example app");
    build_example_step.dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    const run_step = b.step("run-example", "Run the example app");
    run_step.dependOn(&run_example.step);
}
