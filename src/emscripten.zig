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

    const sdl = b.dependency("sdl", .{});

    // The Emscripten sysroot is not bundled with Zig; it's provided by emsdk and populated the
    // first time `emcc` runs.
    const include_path = root.SystemPaths.print_missing_system_path_option(
        paths.include,
        "include_path ($EMSDK/upstream/emscripten/cache/sysroot/include)",
        "Emscripten",
    );
    lib.root_module.addSystemIncludePath(include_path);

    // Zig's UBSan runtime can't be built for Emscripten, and the final link is done by `emcc`
    // which doesn't provide it by default, so trap on undefined behavior instead of calling into a
    // runtime. Other optimize modes don't sanitize C code by default.
    switch (lib.root_module.optimize orelse std.builtin.OptimizeMode.Debug) {
        .Debug, .ReleaseSafe => lib.root_module.sanitize_c = .trap,
        .ReleaseFast, .ReleaseSmall => {},
    }

    // Add the platform specific sources. Threads are disabled by default on Emscripten (enabling
    // them requires `-pthread` and cross-origin isolation), so only the generic thread stubs are
    // needed.
    lib.root_module.addCMacro("GL_GLEXT_PROTOTYPES", "1");
    lib.root_module.addCSourceFiles(.{
        // The core/video/audio/sensor/camera Emscripten sources live in the generic group that
        // build.zig already compiles for every target; listing them here too duplicates them.
        .files = &(sources.emscripten ++ sources.thread_generic),
        .root = sdl.path("src"),
        .flags = root.flags,
    });

    // Set the platform specific build config, mirroring `cmake/PreseedEmscriptenCache.cmake` and
    // the Emscripten section of upstream's `CMakeLists.txt`.
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

        // C library functions
        .HAVE_MALLOC = 1,
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
        .HAVE_WCSCMP = 1,
        .HAVE_WCSNCMP = 1,
        .HAVE_WCSSTR = 1,
        .HAVE_WCSTOL = 1,
        .HAVE_STRLEN = 1,
        .HAVE_STRNLEN = 1,
        .HAVE_STRLCPY = 1,
        .HAVE_STRLCAT = 1,
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
        .HAVE__EXIT = 1,
        .HAVE_FOPEN64 = 1,
        .HAVE_FSEEKO = 1,
        .HAVE_FSEEKO64 = 1,
        .HAVE_SIGACTION = 1,
        .HAVE_SA_SIGACTION = 1,
        .HAVE_ST_MTIM = 1,
        .HAVE_SETJMP = 1,
        .HAVE_NANOSLEEP = 1,
        .HAVE_GMTIME_R = 1,
        .HAVE_LOCALTIME_R = 1,
        .HAVE_NL_LANGINFO = 1,
        .HAVE_SYSCONF = 1,
        .HAVE_CLOCK_GETTIME = 1,
        .HAVE_GETPAGESIZE = 1,
        .HAVE_O_CLOEXEC = 1,
        .HAVE_POSIX_FALLOCATE = 1,
        .HAVE_FDATASYNC = 1,
        .HAVE_SIGTIMEDWAIT = 1,

        // Enable various audio drivers
        .SDL_AUDIO_DRIVER_EMSCRIPTEN = 1,

        // Enable various input drivers. There's no HIDAPI or haptics in the browser.
        .SDL_HIDAPI_DISABLED = 1,
        .SDL_JOYSTICK_EMSCRIPTEN = 1,
        .SDL_JOYSTICK_VIRTUAL = 1,
        .SDL_HAPTIC_DUMMY = 1,
        .SDL_SENSOR_EMSCRIPTEN = 1,

        // Enable various process implementations
        .SDL_PROCESS_DUMMY = 1,

        // Enable various shared object loading systems. Emscripten has no general purpose dynamic
        // library loading, and upstream disables the dynamic API on this platform.
        .SDL_LOADSO_DUMMY = 1,

        // Disable threads, matching upstream's default for Emscripten without `-pthread`
        .SDL_THREADS_DISABLED = 1,

        // Enable various RTC systems
        .SDL_TIME_UNIX = 1,

        // Enable various timer systems
        .SDL_TIMER_UNIX = 1,

        // Enable various video drivers
        .SDL_VIDEO_DRIVER_EMSCRIPTEN = 1,

        // Enable video render APIs. The browser only exposes WebGL, which maps to GLES2.
        .SDL_VIDEO_RENDER_OGL_ES2 = 1,
        .SDL_VIDEO_OPENGL_ES2 = 1,

        // Enable system power support
        .SDL_POWER_EMSCRIPTEN = 1,

        // The browser has no Steam client
        .SDL_STORAGE_STEAM = 0,

        // Enable filesystem support
        .SDL_FILESYSTEM_EMSCRIPTEN = 1,
        .SDL_FSOPS_POSIX = 1,

        // Enable camera driver
        .SDL_CAMERA_DRIVER_EMSCRIPTEN = 1,
        .SDL_CAMERA_DRIVER_DUMMY = 1,

        // Enable the dummy dialog/tray implementations, there's no native equivalent in the browser
        .SDL_DIALOG_DUMMY = 1,
        .SDL_TRAY_DUMMY = 1,

        // Unused
        .HAVE_PTHREAD_SETNAME_NP = 0,
        .HAVE_SYSCTLBYNAME = 0,
        .SDL_AUDIO_DRIVER_COREAUDIO = 0,
        .SDL_AUDIO_DRIVER_ALSA_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_JACK_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_PIPEWIRE_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_PULSEAUDIO_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_SNDIO_DYNAMIC = "",
        .SDL_JOYSTICK_MFI = 0,
        .SDL_LIBUSB_DYNAMIC = "",
        .SDL_UDEV_DYNAMIC = "",
        .SDL_VIDEO_DRIVER_UIKIT = 0,
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
        .SDL_VIDEO_DRIVER_X11_DYNAMIC_XTEST = "",
        .SDL_VIDEO_DRIVER_X11_XINPUT2_SUPPORTS_GESTURE = "",
        .SDL_VIDEO_RENDER_METAL = 0,
        .SDL_VIDEO_METAL = 0,
        .SDL_GPU_METAL = 0,
        .SDL_SENSOR_COREMOTION = 0,
        .SDL_POWER_UIKIT = 0,
        .SDL_FILESYSTEM_COCOA = 0,
        .SDL_CAMERA_DRIVER_COREMEDIA = 0,
        .SDL_CAMERA_DRIVER_PIPEWIRE_DYNAMIC = "",
        .SDL_LIBDECOR_VERSION_MAJOR = "",
        .SDL_LIBDECOR_VERSION_MINOR = "",
        .SDL_LIBDECOR_VERSION_PATCH = "",
        .SDL_FRIBIDI_DYNAMIC = "",
        .SDL_LIBTHAI_DYNAMIC = "",
        .SDL_XKBCOMMON_VERSION_MAJOR = "",
        .SDL_XKBCOMMON_VERSION_MINOR = "",
        .SDL_XKBCOMMON_VERSION_PATCH = "",
        .SDL_IPHONE_KEYBOARD = 0,
        .SDL_IPHONE_LAUNCHSCREEN = 0,
        .SDL_EMSCRIPTEN_PERSISTENT_PATH_STRING = "",
    });
}
