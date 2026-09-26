const std = @import("std");
const sources = @import("sdl.zon");
const root = @import("../build.zig");

pub fn build(
    b: *std.Build,
    target: std.Target,
    lib: *std.Build.Step.Compile,
    build_config_h: *std.Build.Step.ConfigHeader,
    paths: root.SystemPaths,
) void {
    _ = target;

    const upstream = b.dependency("sdl", .{});

    // The iOS SDK is not bundled with Zig, so its headers and frameworks have to be passed in.
    const SystemPaths = root.SystemPaths;
    const framework_path = SystemPaths.print_missing_system_path_option(paths.framework, "framework_path", "iOS");
    lib.root_module.addSystemIncludePath(SystemPaths.print_missing_system_path_option(paths.include, "include_path", "iOS"));
    lib.root_module.addSystemFrameworkPath(framework_path);
    // UIKit.framework's headers reach into UIUtilities.framework, which lives in the sibling
    // SubFrameworks dir, not Frameworks. Apple's clang driver adds this search path implicitly;
    // a plain `-F .../Frameworks` doesn't.
    lib.root_module.addSystemFrameworkPath(framework_path.dirname().path(b, "SubFrameworks"));
    if (paths.library) |p| lib.root_module.addLibraryPath(p);

    // Link with the platform specific system frameworks
    lib.root_module.linkFramework("UIKit", .{});
    lib.root_module.linkFramework("Foundation", .{});
    lib.root_module.linkFramework("CoreGraphics", .{});
    lib.root_module.linkFramework("CoreVideo", .{});
    lib.root_module.linkFramework("CoreMedia", .{});
    lib.root_module.linkFramework("CoreMotion", .{});
    lib.root_module.linkFramework("CoreAudio", .{});
    lib.root_module.linkFramework("AudioToolbox", .{});
    lib.root_module.linkFramework("AVFoundation", .{});
    lib.root_module.linkFramework("QuartzCore", .{});
    lib.root_module.linkFramework("Metal", .{});
    // `SDL_uikitopengles.m` and `SDL_uikitopenglview.m` use EAGL.
    lib.root_module.linkFramework("OpenGLES", .{});
    // `SDL_mfijoystick.m` uses `CHHapticEngine` for controller rumble, and both frameworks are
    // unavailable on the oldest deployment targets SDL supports.
    lib.root_module.linkFramework("GameController", .{ .weak = true });
    lib.root_module.linkFramework("CoreHaptics", .{ .weak = true });

    // Add the platform specific sources
    const objc_flags = root.flags.* ++ [_][]const u8{"-fobjc-arc"};
    lib.root_module.addCSourceFiles(.{
        .files = &(sources.uikit ++ sources.apple ++ sources.pthread),
        .root = upstream.path("src"),
        .flags = &objc_flags,
    });

    // Set the platform specific build config
    build_config_h.addValues(.{
        .HAVE_GCC_ATOMICS = 1,

        // Useful headers
        .HAVE_FLOAT_H = 1,
        .HAVE_STDARG_H = 1,
        .HAVE_STDDEF_H = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_LIBC = 1,
        .HAVE_ALLOCA_H = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_LIMITS_H = 1,
        .HAVE_MATH_H = 1,
        .HAVE_SIGNAL_H = 1,
        .HAVE_STDIO_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_WCHAR_H = 1,

        // C library functions
        .HAVE_DLOPEN = 1,
        .HAVE_MALLOC = 1,
        .HAVE_GETENV = 1,
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
        .HAVE_WCSCMP = 1,
        .HAVE_WCSNCMP = 1,
        .HAVE_STRLEN = 1,
        .HAVE_STRNLEN = 1,
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
        .HAVE_STRPBRK = 1,
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
        .HAVE_FSEEKO = 1,
        .HAVE_SIGACTION = 1,
        .HAVE_SA_SIGACTION = 1,
        .HAVE_SETJMP = 1,
        .HAVE_NANOSLEEP = 1,
        .HAVE_GMTIME_R = 1,
        .HAVE_LOCALTIME_R = 1,
        .HAVE_NL_LANGINFO = 1,
        .HAVE_SYSCONF = 1,
        .HAVE_CLOCK_GETTIME = 1,
        .HAVE_GETPAGESIZE = 1,
        .HAVE_PTHREAD_SETNAME_NP = 1,
        .HAVE_SYSCTLBYNAME = 1,
        .HAVE_O_CLOEXEC = 1,

        // Enable various audio drivers
        .SDL_AUDIO_DRIVER_COREAUDIO = 1,
        .SDL_AUDIO_DRIVER_DISK = 1,
        .SDL_AUDIO_DRIVER_DUMMY = 1,

        // Enable various input drivers. There is no HIDAPI support, iOS does not allow the
        // required USB/Bluetooth access.
        .SDL_JOYSTICK_MFI = 1,
        .SDL_JOYSTICK_VIRTUAL = 1,
        .SDL_HAPTIC_DUMMY = 1,

        // Enable various process implementations. iOS does not allow spawning processes.
        .SDL_PROCESS_DUMMY = 1,

        // Enable the sensor driver
        .SDL_SENSOR_COREMOTION = 1,

        // Enable various shared object loading systems
        .SDL_LOADSO_DLOPEN = 1,

        // Enable various threading systems
        .SDL_THREAD_PTHREAD = 1,
        .SDL_THREAD_PTHREAD_RECURSIVE_MUTEX = 1,

        // Enable various RTC systems
        .SDL_TIME_UNIX = 1,

        // Enable various timer systems
        .SDL_TIMER_UNIX = 1,

        // Enable various video drivers
        .SDL_VIDEO_DRIVER_UIKIT = 1,
        .SDL_VIDEO_DRIVER_DUMMY = 1,

        // Enable video render APIs
        .SDL_VIDEO_RENDER_METAL = 1,
        .SDL_VIDEO_RENDER_GPU = 1,
        .SDL_VIDEO_RENDER_OGL_ES2 = 1,

        // Enable OpenGL ES support. iOS provides it through EAGL, not EGL.
        .SDL_VIDEO_OPENGL_ES = 1,
        .SDL_VIDEO_OPENGL_ES2 = 1,

        // Enable Metal support. Vulkan is left off, it would require a MoltenVK dependency.
        .SDL_VIDEO_METAL = 1,

        // Enable GPU support
        .SDL_GPU_METAL = 1,

        // Enable system power support
        .SDL_POWER_UIKIT = 1,

        // iOS has no Steam client
        .SDL_STORAGE_STEAM = false,

        // Enable filesystem support
        .SDL_FILESYSTEM_COCOA = 1,
        .SDL_FSOPS_POSIX = 1,

        // Enable camera driver
        .SDL_CAMERA_DRIVER_COREMEDIA = 1,
        .SDL_CAMERA_DRIVER_DUMMY = 1,

        // Enable the on-screen keyboard and the launch screen
        .SDL_IPHONE_KEYBOARD = 1,
        .SDL_IPHONE_LAUNCHSCREEN = 1,

        // Enable the dummy dialog and tray implementations, iOS has neither
        .SDL_DIALOG_DUMMY = 1,
        .SDL_TRAY_DUMMY = 1,

        // Unused
        .SDL_AUDIO_DRIVER_ALSA_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_JACK_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_PIPEWIRE_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_PULSEAUDIO_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_SNDIO_DYNAMIC = "",
        .SDL_LIBUSB_DYNAMIC = "",
        .SDL_UDEV_DYNAMIC = "",
        .SDL_VIDEO_DRIVER_KMSDRM_DYNAMIC = "",
        .SDL_VIDEO_DRIVER_KMSDRM_DYNAMIC_GBM = "",
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC = "",
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_CURSOR = "",
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_EGL = "",
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_LIBDECOR = "",
        .SDL_VIDEO_DRIVER_WAYLAND_DYNAMIC_XKBCOMMON = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XCURSOR = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XEXT = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XFIXES = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XINPUT2 = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XRANDR = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XSS = "",
        .SDL_CAMERA_DRIVER_PIPEWIRE_DYNAMIC = "",
        .SDL_LIBDECOR_VERSION_MAJOR = "",
        .SDL_LIBDECOR_VERSION_MINOR = "",
        .SDL_LIBDECOR_VERSION_PATCH = "",
        .SDL_FRIBIDI_DYNAMIC = "",
        .SDL_LIBTHAI_DYNAMIC = "",
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XTEST = "",
        .SDL_VIDEO_DRIVER_X11_XINPUT2_SUPPORTS_GESTURE = "",
        .SDL_XKBCOMMON_VERSION_MAJOR = "",
        .SDL_XKBCOMMON_VERSION_MINOR = "",
        .SDL_XKBCOMMON_VERSION_PATCH = "",
        .SDL_EMSCRIPTEN_PERSISTENT_PATH_STRING = "",
    });
}
