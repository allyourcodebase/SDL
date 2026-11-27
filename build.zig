const std = @import("std");
const linux = @import("src/linux.zig");
const windows = @import("src/windows.zig");
const macos = @import("src/macos.zig");
const ios = @import("src/ios.zig");
const android = @import("src/android.zig");
const build_zon = @import("build.zig.zon");

const assert = std.debug.assert;

pub const sources = @import("src/sdl.zon");

pub const flags = &.{
    "-fno-strict-aliasing",
    "-fvisibility=hidden",
    "-DUSING_GENERATED_CONFIG_H",
};

pub const SystemPaths = struct {
    include: ?std.Build.LazyPath,
    framework: ?std.Build.LazyPath,
    library: ?std.Build.LazyPath,

    pub fn printMissingSystemPathOption(path: ?std.Build.LazyPath, comptime flag: []const u8, comptime platform: []const u8) std.Build.LazyPath {
        return path orelse {
            std.log.err("'-D" ++ flag ++ "' is required when building SDL for " ++ platform, .{});
            std.process.exit(1);
        };
    }
};

pub fn build(b: *std.Build) !void {
    // Get the upstream source and build options
    const upstream = b.dependency("sdl", .{});
    const target = b.standardTargetOptions(.{});
    // https://github.com/allyourcodebase/SDL/issues/42
    const optimize: ?std.builtin.OptimizeMode = b.standardOptimizeOption(.{});

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

    const system_paths: SystemPaths = .{
        .include = b.option(std.Build.LazyPath, "include_path", "SDK include dir, e.g. $(xcrun --sdk iphoneos --show-sdk-path)/usr/include or <ndk sysroot>/usr/include"),
        .framework = b.option(std.Build.LazyPath, "framework_path", "SDK framework dir, e.g. $(xcrun --sdk iphoneos --show-sdk-path)/System/Library/Frameworks"),
        .library = b.option(std.Build.LazyPath, "library_path", "SDK library dir, e.g. $(xcrun --sdk iphoneos --show-sdk-path)/usr/lib"),
    };

    const main_callbacks = b.option(bool, "main_callbacks",
        \\build SDL3_main to enter the app through SDL_AppInit/Iterate/Event/Quit rather
        \\than a classic SDL_main, defaults to false
    ) orelse false;

    // Get the SO version. This is the same as the SDL version, but the major version is elided
    // since it's baked into the name. This mirrors the official build process.
    var sdl_so_version = comptime std.SemanticVersion.parse(build_zon.dependencies.sdl.upstream_version) catch unreachable;
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
    lib.root_module.addCMacro("SDL_VENDOR_INFO", std.fmt.comptimePrint("\"{s} {s}\"", .{
        "https://github.com/allyourcodebase/SDL",
        build_zon.version,
    }));
    lib.installHeadersDirectory(upstream.path("include/SDL3"), "SDL3", .{});
    b.installArtifact(lib);

    // Set the include path
    lib.root_module.addIncludePath(upstream.path("include"));
    lib.root_module.addIncludePath(upstream.path("src"));
    lib.root_module.addIncludePath(upstream.path("src/video/khronos"));

    // Compile the generic sources
    lib.root_module.addCSourceFiles(.{
        .files = &sources.generic,
        .root = upstream.path("src"),
        .flags = flags,
    });

    var maybe_sdl_main_lib: ?*std.Build.Step.Compile = null;
    if (main_callbacks) {
        const sdl_main_lib = b.addLibrary(.{
            .name = "SDL3_main",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
            .linkage = .static,
        });
        sdl_main_lib.root_module.addIncludePath(upstream.path("include"));
        sdl_main_lib.root_module.addCMacro("SDL_MAIN_USE_CALLBACKS", "1");
        sdl_main_lib.root_module.addCSourceFile(.{ .file = b.path("src/sdl_main.c") });
        if (system_paths.include) |p| sdl_main_lib.root_module.addSystemIncludePath(p);
        if (system_paths.framework) |p| sdl_main_lib.root_module.addSystemFrameworkPath(p);
        b.installArtifact(sdl_main_lib);
        maybe_sdl_main_lib = sdl_main_lib;
    }

    if (default_target_config) {
        const build_config_h = b.addConfigHeader(.{
            .style = .{ .cmake = upstream.path("include/build_config/SDL_build_config.h.cmake") },
            .include_path = "SDL_build_config.h",
        }, .{
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
            .SDL_DEFAULT_ASSERT_LEVEL = @as(u2, switch (optimize orelse std.builtin.OptimizeMode.Debug) {
                .Debug, .ReleaseSafe => 2,
                .ReleaseSmall, .ReleaseFast => 1,
            }),
        });
        lib.root_module.addConfigHeader(build_config_h);

        // Configure the build for the target platform
        switch (target.result.os.tag) {
            .linux => if (target.result.abi.isAndroid())
                android.build(b, target.result, lib, build_config_h, system_paths)
            else
                linux.build(b, target.result, lib, build_config_h),
            .windows => windows.build(b, target.result, lib, build_config_h),
            .macos => macos.build(b, target.result, lib, build_config_h, system_paths),
            .ios => ios.build(b, target.result, lib, build_config_h, system_paths),
            else => @panic("target has no default config"),
        }
    }

    // Add the Wayland scanner step
    linux.addWaylandScannerStep(b);

    // Translate the SDL headers and export them as a Zig module
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/sdl.h"),
        .target = target,
        .optimize = optimize orelse std.builtin.OptimizeMode.Debug,
    });
    translate_c.defineCMacro("USING_GENERATED_CONFIG_H", "1");
    translate_c.addIncludePath(upstream.path("include"));
    translate_c.addIncludePath(upstream.path("src/video/khronos"));
    if (system_paths.include) |p| translate_c.addSystemIncludePath(p);
    if (system_paths.framework) |p| translate_c.addSystemFrameworkPath(p);
    const module = translate_c.addModule("sdl3");
    if (system_paths.include) |p| module.addSystemIncludePath(p);
    if (system_paths.framework) |p| module.addSystemFrameworkPath(p);
    if (system_paths.library) |p| module.addLibraryPath(p);
    module.linkLibrary(lib);

    // Add the example
    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("sdl3", module);

    const build_example_step = b.step("example", "Build the example app");
    build_example_step.dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    const run_step = b.step("run-example", "Run the example app");
    run_step.dependOn(&run_example.step);

    // Add a callbacks example. Note, it will fail if no -Dmain_callbacks.
    const build_callbacks_example_step = b.step("callbacks-example", "Build the callbacks example app (requires -Dmain_callbacks)");
    const run_callbacks_step = b.step("run-callbacks-example", "Run the callbacks example app (requires -Dmain_callbacks)");
    if (maybe_sdl_main_lib) |sdl_main_lib| {
        const callbacks_example = b.addExecutable(.{
            .name = "callbacks_example",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/callbacks_example.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        callbacks_example.root_module.addImport("sdl3", module);
        callbacks_example.root_module.linkLibrary(sdl_main_lib);
        build_callbacks_example_step.dependOn(&callbacks_example.step);

        const run_callbacks_example = b.addRunArtifact(callbacks_example);
        run_callbacks_step.dependOn(&run_callbacks_example.step);
    } else {
        const fail = b.addFail("The callbacks example requires -Dmain_callbacks");
        build_callbacks_example_step.dependOn(&fail.step);
        run_callbacks_step.dependOn(&fail.step);
    }
}

/// Fetches a lazy dependency, unless provided via `-fsys`.
///
/// A more typical setup would still need to link to the library in the event that it's provided by
/// `-fsys`, but we can just treat this as a noop as SDL doesn't link to its dependencies, it
/// `dlopen`s them when available. We only pull them in for the headers.
pub fn lazyDependency(
    step: *std.Build.Step,
    name: []const u8,
    args: anytype,
) ?*std.Build.Dependency {
    // If we're using a system integration, return null as no work needs to be done. SDL will
    // `dlopen` the library, if available, at runtime so we don't need to link it here.
    if (step.owner.systemIntegrationOption(name, .{})) return null;
    if (@hasDecl(std.Build, "dependencyStep")) {
        return step.owner.dependencyStep(step, name, args);
    } else {
        // https://github.com/allyourcodebase/SDL/issues/44
        return step.owner.lazyDependency(name, .{});
    }
}

/// Adds an include path via `lazyDependency`, unless provided via `-fsys`.
pub fn addDepIncludePath(
    lib: *std.Build.Step.Compile,
    name: []const u8,
    sub_path: []const u8,
    args: anytype,
) void {
    if (lazyDependency(&lib.step, name, args)) |dep| {
        lib.root_module.addIncludePath(dep.path(sub_path));
    }
}
