const std = @import("std");
const builtin = @import("builtin");
const sources = @import("sdl.zon");
const root = @import("../build.zig");
const Subsystems = root.Subsystems;
const AllDrivers = root.Drivers;

pub fn build(
    b: *std.Build,
    target: std.Target,
    lib: *std.Build.Step.Compile,
    build_config_h: *std.Build.Step.ConfigHeader,
    paths: root.SystemPaths,
) void {
    const upstream = b.dependency("sdl", .{});

    // All third party headers come from the target's sysroot (`-Dinclude_path`/`-Dlibrary_path`),
    // or from the host when building natively on Linux. Nothing is linked, SDL dlopens everything.
    const native = builtin.os.tag == .linux;
    const library: std.Build.LazyPath = if (native)
        paths.library orelse .{ .cwd_relative = b.fmt("/usr/lib/{s}-linux-gnu", .{@tagName(target.cpu.arch)}) }
    else
        root.SystemPaths.print_missing_system_path_option(paths.library, "library_path (<sysroot>/usr/lib/<triple>)", "Linux");
    {
        const include: std.Build.LazyPath = if (native)
            paths.include orelse .{ .cwd_relative = "/usr/include" }
        else
            root.SystemPaths.print_missing_system_path_option(paths.include, "include_path (<sysroot>/usr/include)", "Linux");

        // `-idirafter` so Zig's bundled libc headers win over the sysroot's.
        lib.root_module.addAfterIncludePath(include);
        // The pkg-config `Cflags` of the libraries SDL uses.
        for ([_][]const u8{
            "dbus-1.0",
            "glib-2.0",
            "ibus-1.0",
            "pipewire-0.3",
            "spa-0.2",
            "libdrm",
            "libdecor-0",
            "fribidi",
            "libusb-1.0",
        }) |sub| lib.root_module.addAfterIncludePath(include.path(b, sub));
        // Arch specific config headers (`glibconfig.h`, `dbus/dbus-arch-deps.h`).
        for ([_][]const u8{ "glib-2.0/include", "dbus-1.0/include" }) |sub|
            lib.root_module.addAfterIncludePath(library.path(b, sub));

        lib.root_module.addIncludePath(b.path("deps/wayland/protocols"));
    }

    // Add the platform specific SDL sources
    lib.root_module.addCSourceFiles(.{
        .files = &(sources.unix ++ sources.unix_dialog ++ sources.unix_tray ++ sources.linux ++ sources.x11 ++ sources.pthread),
        .root = upstream.path("src"),
        .flags = root.flags,
    });

    // Provide the Wayland protocols
    for (@as([]const []const u8, &sources.wayland_protocols)) |xml| {
        lib.root_module.addCSourceFile(.{
            .file = b.path(b.pathJoin(&.{
                "deps",
                "wayland",
                "protocols",
                b.fmt("{s}-client.c", .{std.fs.path.stem(xml)}),
            })),
            .flags = root.flags,
        });
    }

    // Set the platform specific build config
    //
    // Dynamic library versions are from Steam Linux Runtime 3.0 Sniper unless otherwise noted:
    // https://gitlab.steamos.cloud/steamrt/steamrt/-/tree/steamrt/sniper
    //
    // SDL gates some API use on these, so like SDL's CMake we take them from the sysroot's pkg-config.
    const libdecor_version = pkgConfigVersion(b, library, "libdecor-0", .{ .major = 0, .minor = 1, .patch = 0 });
    const xkbcommon_version = pkgConfigVersion(b, library, "xkbcommon", .{ .major = 0, .minor = 5, .patch = 0 });
    const have_sigtimedwait: i64 = if (target.os.tag == .openbsd) 0 else 1;
    build_config_h.addValues(.{
        .HAVE_GCC_ATOMICS = 1,

        // Useful headers
        .HAVE_FLOAT_H = 1,
        .HAVE_STDARG_H = 1,
        .HAVE_STDDEF_H = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_LIBC = 1,
        .HAVE_ALLOCA_H = 1,
        .HAVE_ICONV_H = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_LIMITS_H = 1,
        .HAVE_MALLOC_H = 1,
        .HAVE_MATH_H = 1,
        .HAVE_MEMORY_H = 1,
        .HAVE_SIGNAL_H = 1,
        .HAVE_STDIO_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_WCHAR_H = 1,
        .HAVE_DLOPEN = 1,
        .HAVE_MALLOC = 1,
        .HAVE_FDATASYNC = 1,
        .HAVE_GETENV = 1,
        .HAVE_GETHOSTNAME = 1,
        .HAVE_SETENV = 1,
        .HAVE_PUTENV = 1,
        .HAVE_UNSETENV = 1,
        .HAVE_ABS = 1,
        .HAVE_BCOPY = 1,
        .HAVE_MEMSET = 1,
        .HAVE_MEMCPY = 1,
        .HAVE_MEMMOVE = 1,
        .HAVE_MEMCMP = 1,
        .HAVE_WCSLEN = 1,
        .HAVE_WCSNLEN = 1,
        .HAVE_WCSSTR = 1,
        .HAVE_WCSCMP = 1,
        .HAVE_WCSNCMP = 1,
        .HAVE_WCSTOL = 1,
        .HAVE_STRLEN = 1,
        .HAVE_STRNLEN = 1,
        .HAVE_STRPBRK = 1,
        .HAVE_INDEX = 1,
        .HAVE_RINDEX = 1,
        .HAVE_STRCHR = 1,
        .HAVE_STRRCHR = 1,
        .HAVE_STRSTR = 1,
        .HAVE_STRTOK_R = 1,
        .HAVE_STRTOL = 1,
        .HAVE_STRTOUL = 1,
        .HAVE_STRTOLL = 1,
        .HAVE_STRTOULL = 1,
        .HAVE_STRTOD = 1,
        .HAVE_ATOI = 1,
        .HAVE_ATOF = 1,
        .HAVE_STRCMP = 1,
        .HAVE_STRNCMP = 1,
        .HAVE_VSSCANF = 1,
        .HAVE_VSNPRINTF = 1,
        .HAVE_ACOS = 1,
        .HAVE_ACOSF = 1,
        .HAVE_ASIN = 1,
        .HAVE_ASINF = 1,
        .HAVE_ATAN = 1,
        .HAVE_ATANF = 1,
        .HAVE_ATAN2 = 1,
        .HAVE_ATAN2F = 1,
        .HAVE_CEIL = 1,
        .HAVE_CEILF = 1,
        .HAVE_COPYSIGN = 1,
        .HAVE_COPYSIGNF = 1,
        .HAVE__COPYSIGN = 1,
        .HAVE_COS = 1,
        .HAVE_COSF = 1,
        .HAVE_EXP = 1,
        .HAVE_EXPF = 1,
        .HAVE_FABS = 1,
        .HAVE_FABSF = 1,
        .HAVE_FLOOR = 1,
        .HAVE_FLOORF = 1,
        .HAVE_FMOD = 1,
        .HAVE_FMODF = 1,
        .HAVE_ISINF = 1,
        .HAVE_ISINFF = 1,
        .HAVE_ISINF_FLOAT_MACRO = 1,
        .HAVE_ISNAN = 1,
        .HAVE_ISNANF = 1,
        .HAVE_ISNAN_FLOAT_MACRO = 1,
        .HAVE_LOG = 1,
        .HAVE_LOGF = 1,
        .HAVE_LOG10 = 1,
        .HAVE_LOG10F = 1,
        .HAVE_LROUND = 1,
        .HAVE_LROUNDF = 1,
        .HAVE_MODF = 1,
        .HAVE_MODFF = 1,
        .HAVE_POW = 1,
        .HAVE_POWF = 1,
        .HAVE_ROUND = 1,
        .HAVE_ROUNDF = 1,
        .HAVE_SCALBN = 1,
        .HAVE_SCALBNF = 1,
        .HAVE_SIN = 1,
        .HAVE_SINF = 1,
        .HAVE_SQRT = 1,
        .HAVE_SQRTF = 1,
        .HAVE_TAN = 1,
        .HAVE_TANF = 1,
        .HAVE_TRUNC = 1,
        .HAVE_TRUNCF = 1,
        .HAVE__FSEEKI64 = 1,
        .HAVE_FOPEN64 = 1,
        .HAVE_FSEEKO = 1,
        .HAVE_FSEEKO64 = 1,
        .HAVE_MEMFD_CREATE = 1,
        .HAVE_POSIX_FALLOCATE = 1,
        .HAVE_SIGACTION = 1,
        .HAVE_SA_SIGACTION = 1,
        .HAVE_SIGTIMEDWAIT = have_sigtimedwait,
        .HAVE_ST_MTIM = 1,
        .HAVE_SETJMP = 1,
        .HAVE_NANOSLEEP = 1,
        .HAVE_GMTIME_R = 1,
        .HAVE_LOCALTIME_R = 1,
        .HAVE_NL_LANGINFO = 1,
        .HAVE_SYSCONF = 1,
        .HAVE_CLOCK_GETTIME = 1,
        .HAVE_GETPAGESIZE = 1,
        .HAVE_ICONV = 1,
        .SDL_USE_LIBICONV = 1,
        .HAVE_PTHREAD_SETNAME_NP = 1,
        .HAVE_SEM_TIMEDWAIT = 1,
        .HAVE_GETAUXVAL = 1,
        .HAVE_ELF_AUX_INFO = 1,
        .HAVE_PPOLL = 1,
        .HAVE__EXIT = 1,
        .HAVE_GETRESUID = 1,
        .HAVE_GETRESGID = 1,

        .HAVE_DBUS_DBUS_H = 1,
        .HAVE_FCITX = 1,
        .HAVE_IBUS_IBUS_H = 1,
        .HAVE_INOTIFY_INIT1 = 1,
        .HAVE_INOTIFY = 1,
        .HAVE_LIBUSB = 1,
        .HAVE_O_CLOEXEC = 1,

        .HAVE_LINUX_INPUT_H = 1,
        .HAVE_LIBUDEV_H = 1,
        .HAVE_LIBDECOR_H = 1,
        .HAVE_LIBURING_H = 1,
        .HAVE_FRIBIDI_H = 1,
        .SDL_FRIBIDI_DYNAMIC = formatDynamic("libfribidi.so.0"),
        .HAVE_LIBTHAI_H = 1,
        .SDL_LIBTHAI_DYNAMIC = formatDynamic("libthai.so.0"),

        .USE_POSIX_SPAWN = 1,

        // Enable various audio drivers
        .SDL_AUDIO_DRIVER_ALSA = 1,
        .SDL_AUDIO_DRIVER_ALSA_DYNAMIC = formatDynamic("libasound.so.2"),
        .SDL_AUDIO_DRIVER_JACK = 1,
        .SDL_AUDIO_DRIVER_JACK_DYNAMIC = formatDynamic("libjack.so.0"),
        .SDL_AUDIO_DRIVER_OSS = 1,
        .SDL_AUDIO_DRIVER_PIPEWIRE = 1,
        .SDL_AUDIO_DRIVER_PIPEWIRE_DYNAMIC = formatDynamic("libpipewire-0.3.so.0"),
        .SDL_AUDIO_DRIVER_PULSEAUDIO = 1,
        .SDL_AUDIO_DRIVER_PULSEAUDIO_DYNAMIC = formatDynamic("libpulse.so.0"),
        .SDL_AUDIO_DRIVER_SNDIO = 1,
        // Note that `libsndio` is not part of the SLR.
        .SDL_AUDIO_DRIVER_SNDIO_DYNAMIC = formatDynamic("libsndio.so.7"),
        .SDL_AUDIO_DRIVER_DUMMY = 1,

        // Enable various input drivers
        .SDL_INPUT_LINUXEV = 1,
        .SDL_INPUT_LINUXKD = 1,
        .SDL_HAVE_MACHINE_JOYSTICK_H = 1,
        .SDL_JOYSTICK_HIDAPI = 1,
        .SDL_JOYSTICK_LINUX = 1,
        .SDL_JOYSTICK_VIRTUAL = 1,
        .SDL_HAPTIC_LINUX = 1,

        .SDL_LIBUSB_DYNAMIC = formatDynamic("libusb-1.0.so.0"),
        .SDL_UDEV_DYNAMIC = formatDynamic("libudev.so.1"),

        // Enable various process implementations
        .SDL_PROCESS_POSIX = 1,

        // Enable the sensor driver
        .SDL_SENSOR_DUMMY = 1,

        // Enable various shared object loading systems
        .SDL_LOADSO_DLOPEN = 1,

        // Enable various threading systems
        .SDL_THREAD_PTHREAD = 1,
        .SDL_THREAD_PTHREAD_RECURSIVE_MUTEX = 1,

        // Enable various RTC systems
        .SDL_TIME_UNIX = 1,

        // Enable various timer systems
        .SDL_TIMER_UNIX = 1,

        // Enable various video drivers. Note that we *don't* specify known good versions here,
        // because SDL doesn't either--when you make an SDL build you end up with a version number,
        // but it isn't a known good version it's just whatever you happen to have on your computer.
        // If you were to copy that in, you'd make your application less portable without actually
        // getting any guarantees about correctness.
        .SDL_VIDEO_DRIVER_KMSDRM = 1,
        .SDL_VIDEO_DRIVER_KMSDRM_DYNAMIC = formatDynamic("libdrm.so.2"),
        .SDL_VIDEO_DRIVER_KMSDRM_DYNAMIC_GBM = formatDynamic("libgbm.so.1"),
        .SDL_VIDEO_DRIVER_ROCKCHIP = 1,
        .SDL_VIDEO_DRIVER_OPENVR = 0, // https://github.com/libsdl-org/SDL/issues/11329
        .SDL_VIDEO_DRIVER_WAYLAND = 1,
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC = formatDynamic("libwayland-client.so.0"),
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_CURSOR = formatDynamic("libwayland-cursor.so.0"),
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_EGL = formatDynamic("libwayland-egl.so.1"),
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_LIBDECOR = formatDynamic("libdecor-0.so.0"),
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_XKBCOMMON = formatDynamic("libxkbcommon.so.0"),
        .SDL_VIDEO_DRIVER_X11 = 1,
        .SDL_VIDEO_DRIVER_X11_DYNAMIC = formatDynamic("libX11.so.6"),
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XEXT = formatDynamic("libXext.so.6"),
        .SDL_VIDEO_DRIVER_X11_XFIXES = 1,
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XFIXES = formatDynamic("libXfixes.so.3"),
        .SDL_VIDEO_DRIVER_X11_XINPUT2 = 1,
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XINPUT2 = formatDynamic("libXi.so.6"),
        .SDL_VIDEO_DRIVER_X11_XRANDR = 1,
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XRANDR = formatDynamic("libXrandr.so.2"),
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XSS = formatDynamic("libXss.so.1"),
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XTEST = formatDynamic("libXtst.so.6"),
        .SDL_VIDEO_DRIVER_X11_XCURSOR = 1,
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XCURSOR = formatDynamic("libXcursor.so.1"),
        .SDL_VIDEO_DRIVER_X11_HAS_XKBLIB = 1,
        .SDL_VIDEO_DRIVER_X11_SUPPORTS_GENERIC_EVENTS = 1,
        .SDL_VIDEO_DRIVER_X11_XDBE = 1,
        .SDL_VIDEO_DRIVER_X11_XINPUT2_SUPPORTS_MULTITOUCH = 1,
        .SDL_VIDEO_DRIVER_X11_XINPUT2_SUPPORTS_SCROLLINFO = 1,
        .SDL_VIDEO_DRIVER_X11_XINPUT2_SUPPORTS_GESTURE = 1,
        .SDL_VIDEO_DRIVER_X11_XSCRNSAVER = 1,
        .SDL_VIDEO_DRIVER_X11_XSHAPE = 1,
        .SDL_VIDEO_DRIVER_X11_XSYNC = 1,
        .SDL_VIDEO_DRIVER_DUMMY = 1,

        // Enable video render APIs
        .SDL_VIDEO_RENDER_GPU = 1,
        .SDL_VIDEO_RENDER_VULKAN = 1,
        .SDL_VIDEO_RENDER_OGL = 1,
        .SDL_VIDEO_RENDER_OGL_ES2 = 1,

        // Render APIs
        .SDL_VIDEO_OPENGL = 1,
        .SDL_VIDEO_OPENGL_ES = 1,
        .SDL_VIDEO_OPENGL_ES2 = 1,
        .SDL_VIDEO_OPENGL_CGL = 1,
        .SDL_VIDEO_OPENGL_GLX = 1,
        .SDL_VIDEO_OPENGL_EGL = 1,
        .SDL_VIDEO_VULKAN = 1,

        // Enable GPU support
        .SDL_GPU_VULKAN = 1,

        // Enable system power support
        .SDL_POWER_LINUX = 1,

        // Enable system filesystem support
        .SDL_FILESYSTEM_UNIX = 1,

        // Enable system storage support
        .SDL_STORAGE_STEAM = 1,

        // Enable system FSops support
        .SDL_FSOPS_POSIX = 1,

        // Enable camera subsystem
        .SDL_CAMERA_DRIVER_V4L2 = 1,
        .SDL_CAMERA_DRIVER_PIPEWIRE = 1,
        .SDL_CAMERA_DRIVER_PIPEWIRE_DYNAMIC = formatDynamic("libpipewire-0.3.so.0"),
        .SDL_CAMERA_DRIVER_DUMMY = 1,

        // Whether SDL_DYNAMIC_API needs dlopen
        .DYNAPI_NEEDS_DLOPEN = 1,

        // Enable ime support
        .SDL_USE_IME = 1,

        // Set the xkbcommon version
        .SDL_XKBCOMMON_VERSION_MAJOR = @as(i64, @intCast(xkbcommon_version.major)),
        .SDL_XKBCOMMON_VERSION_MINOR = @as(i64, @intCast(xkbcommon_version.minor)),
        .SDL_XKBCOMMON_VERSION_PATCH = @as(i64, @intCast(xkbcommon_version.patch)),

        // Set the libdecor version
        .SDL_LIBDECOR_VERSION_MAJOR = @as(i64, @intCast(libdecor_version.major)),
        .SDL_LIBDECOR_VERSION_MINOR = @as(i64, @intCast(libdecor_version.minor)),
        .SDL_LIBDECOR_VERSION_PATCH = @as(i64, @intCast(libdecor_version.patch)),

        // Unused
        .SDL_EMSCRIPTEN_PERSISTENT_PATH_STRING = "",
    });
}

/// A build step for updating the cached Wayland protocols. This isn't built into the the normal
/// build process to avoid having to build the wayland-scanner and its dependencies from source,
/// instead you must have `wayland-scanner` available on your path when you update Wayland or to
/// a version of SDL that requires new Wayland protocols.
pub fn addWaylandScannerStep(b: *std.Build) void {
    const upstream = b.dependency("sdl", .{});
    const update_wayland_protocols = b.addUpdateSourceFiles();
    const generate_wayland_protocols = b.step(
        "wayland-scanner",
        "Regenerate the required Wayland protocols.",
    );
    generate_wayland_protocols.dependOn(&update_wayland_protocols.step);

    for (@as([]const []const u8, &sources.wayland_protocols)) |xml| {
        const generate_header = b.addSystemCommand(&.{ "wayland-scanner", "client-header" });
        generate_header.addFileArg(upstream.path(b.pathJoin(&.{ "wayland-protocols", xml })));
        const header_name = b.fmt("{s}-client-protocol.h", .{std.fs.path.stem(xml)});
        const header = generate_header.addOutputFileArg(header_name);
        update_wayland_protocols.addCopyFileToSource(header, b.pathJoin(&.{
            "deps",
            "wayland",
            "protocols",
            header_name,
        }));

        const generate_source = b.addSystemCommand(&.{ "wayland-scanner", "private-code" });
        generate_source.addFileArg(upstream.path(b.pathJoin(&.{ "wayland-protocols", xml })));
        const source_name = b.fmt("{s}-client.c", .{std.fs.path.stem(xml)});
        const source = generate_source.addOutputFileArg(source_name);
        update_wayland_protocols.addCopyFileToSource(source, b.pathJoin(&.{
            "deps",
            "wayland",
            "protocols",
            source_name,
        }));
    }
}

/// Reads `Version:` from `<library>/pkgconfig/<name>.pc`, falling back to SDL's lowest supported.
fn pkgConfigVersion(b: *std.Build, library: std.Build.LazyPath, name: []const u8, fallback: std.SemanticVersion) std.SemanticVersion {
    const pc_path = library.path(b, b.fmt("pkgconfig/{s}.pc", .{name})).getPath(b);
    const pc = std.Io.Dir.cwd().readFileAlloc(b.graph.io, pc_path, b.allocator, .limited(64 * 1024)) catch {
        std.log.warn("{s} not found, assuming {s} {f}", .{ pc_path, name, fallback });
        return fallback;
    };
    var lines = std.mem.tokenizeScalar(u8, pc, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "Version:")) continue;
        const version = std.mem.trim(u8, line["Version:".len..], " \t\r");
        return std.SemanticVersion.parse(version) catch break;
    }
    std.log.warn("no version in {s}, assuming {s} {f}", .{ pc_path, name, fallback });
    return fallback;
}

fn formatDynamic(comptime name: []const u8) []const u8 {
    return std.fmt.comptimePrint("\"{s}\"", .{name});
}
