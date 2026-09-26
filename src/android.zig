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
    // NDK headers are not bundled with Zig; bionic's arch-specific headers (e.g. `jni.h`
    // adjacent files, `<triple>/asm/...`) live in a per-triple subdirectory of usr/include.
    const include_path = root.SystemPaths.print_missing_system_path_option(
        paths.include,
        "include_path (<ndk>/toolchains/llvm/prebuilt/<host>/sysroot/usr/include)",
        "Android",
    );
    const triple = switch (target.cpu.arch) {
        .x86 => "i686-linux-android",
        .x86_64 => "x86_64-linux-android",
        .arm => "arm-linux-androideabi",
        .aarch64 => "aarch64-linux-android",
        else => @panic("unsupported Android arch"),
    };
    lib.root_module.addSystemIncludePath(include_path);
    lib.root_module.addSystemIncludePath(include_path.path(b, triple));
    // Android apps load native code only as JNI shared libraries, so the static lib is always linked into a .so.
    lib.root_module.pic = true;

    const arm = target.cpu.arch.isArm();
    const vulkan_capable = !arm;

    // Add the platform specific sources
    lib.root_module.addCMacro("GL_GLEXT_PROTOTYPES", "1");
    lib.root_module.addCSourceFiles(.{
        // The core/video/audio/sensor/camera Android sources live in the generic group that
        // build.zig already compiles for every target; listing them here too duplicates them.
        .files = &(sources.android ++ sources.pthread),
        .root = b.dependency("sdl", .{}).path("src"),
        .flags = root.flags,
    });
    // SDL_android.c registers HIDDeviceManager_tab, which only hid.cpp defines; with
    // SDL_HIDAPI_DISABLED it compiles to JNI stubs that use no C++ stdlib.
    lib.root_module.addCSourceFile(.{
        .file = b.dependency("sdl", .{}).path("src/hidapi/android/hid.cpp"),
        .flags = &(root.flags.* ++ [_][]const u8{ "-fno-exceptions", "-fno-rtti" }),
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
        .HAVE_STRING_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_WCHAR_H = 1,

        // C library functions
        .HAVE_DLOPEN = 1,
        .HAVE_MALLOC = 1,
        .HAVE_CALLOC = 1,
        .HAVE_REALLOC = 1,
        .HAVE_FREE = 1,
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
        .HAVE_STRLEN = 1,
        .HAVE_STRLCPY = 1,
        .HAVE_STRLCAT = 1,
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
        .HAVE_ISINF_FLOAT_MACRO = 1,
        .HAVE_ISNAN = 1,
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
        .HAVE_SIGACTION = 1,
        .HAVE_SETJMP = 1,
        .HAVE_NANOSLEEP = 1,
        .HAVE_GMTIME_R = 1,
        .HAVE_LOCALTIME_R = 1,
        .HAVE_SYSCONF = 1,
        .HAVE_CLOCK_GETTIME = 1,
        .HAVE_O_CLOEXEC = 1,

        // Enable various audio drivers
        .SDL_AUDIO_DRIVER_OPENSLES = 1,
        .SDL_AUDIO_DRIVER_AAUDIO = 1,
        .SDL_AUDIO_DRIVER_DUMMY = 1,

        // Enable various input drivers. HIDAPI stays off, matching upstream's default posture on
        // Android (it still needs `hid.cpp` to compile for the JNI HIDDeviceManager stubs).
        .SDL_HIDAPI_DISABLED = 1,
        .SDL_JOYSTICK_ANDROID = 1,
        .SDL_JOYSTICK_VIRTUAL = 1,
        .SDL_HAPTIC_ANDROID = 1,
        .SDL_SENSOR_ANDROID = 1,

        // Enable various process implementations
        .SDL_PROCESS_DUMMY = 1,

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
        .SDL_VIDEO_DRIVER_ANDROID = 1,
        .SDL_VIDEO_DRIVER_DUMMY = 1,

        // Enable video render APIs. GPU/Vulkan need a non-32-bit-arm target (matches upstream:
        // no 32-bit ARM Vulkan ICDs to speak of).
        .SDL_VIDEO_RENDER_GPU = vulkan_capable,
        .SDL_VIDEO_RENDER_VULKAN = vulkan_capable,
        .SDL_VIDEO_RENDER_OGL_ES2 = 1,
        .SDL_VIDEO_OPENGL_ES = 1,
        .SDL_VIDEO_OPENGL_ES2 = 1,
        .SDL_VIDEO_OPENGL_EGL = 1,
        .SDL_VIDEO_VULKAN = vulkan_capable,
        .SDL_GPU_VULKAN = vulkan_capable,

        // Enable system power support
        .SDL_POWER_ANDROID = 1,

        // Android has no Steam client
        .SDL_STORAGE_STEAM = false,

        // Enable filesystem support
        .SDL_FILESYSTEM_ANDROID = 1,
        .SDL_FSOPS_POSIX = 1,

        // Enable camera driver
        .SDL_CAMERA_DRIVER_ANDROID = 1,
        .SDL_CAMERA_DRIVER_DUMMY = 1,

        // Enable the dummy dialog/tray implementations; SDL has no Android tray, and the
        // Android dialog implementation is Java-side (`dialog/android/SDL_androiddialog.c`
        // just JNI-calls into it, no separate dummy needed here).
        .SDL_DIALOG_DUMMY = false,
        .SDL_TRAY_DUMMY = 1,

        .DYNAPI_NEEDS_DLOPEN = 1,

        // Unused
        .HAVE_STRINGS_H = false,
        .HAVE_MALLOC_H = false,
        .HAVE_MEMORY_H = false,
        .HAVE_WCSLEN = false,
        .HAVE_WCSNLEN = false,
        .HAVE_WCSCMP = false,
        .HAVE_WCSNCMP = false,
        .HAVE_STRNLEN = false,
        .HAVE_STRPBRK = false,
        .HAVE_FSEEKO = false,
        .HAVE_SA_SIGACTION = false,
        .HAVE_NL_LANGINFO = false,
        .HAVE_GETPAGESIZE = false,
        .HAVE_MPROTECT = false,
        .HAVE_PTHREAD_SETNAME_NP = false,
        .HAVE_SYSCTL = false,
        .HAVE_SYSCTLBYNAME = false,
        .SDL_AUDIO_DRIVER_COREAUDIO = false,
        .SDL_AUDIO_DRIVER_ALSA_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_JACK_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_PIPEWIRE_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_PULSEAUDIO_DYNAMIC = "",
        .SDL_AUDIO_DRIVER_SNDIO_DYNAMIC = "",
        .SDL_JOYSTICK_MFI = false,
        .SDL_LIBUSB_DYNAMIC = "",
        .SDL_UDEV_DYNAMIC = "",
        .SDL_VIDEO_DRIVER_UIKIT = false,
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
        .SDL_VIDEO_RENDER_METAL = false,
        .SDL_VIDEO_METAL = false,
        .SDL_GPU_METAL = false,
        .SDL_SENSOR_COREMOTION = false,
        .SDL_POWER_UIKIT = false,
        .SDL_FILESYSTEM_COCOA = false,
        .SDL_CAMERA_DRIVER_COREMEDIA = false,
        .SDL_CAMERA_DRIVER_PIPEWIRE_DYNAMIC = "",
        .SDL_LIBDECOR_VERSION_MAJOR = "",
        .SDL_LIBDECOR_VERSION_MINOR = "",
        .SDL_LIBDECOR_VERSION_PATCH = "",
        .SDL_FRIBIDI_DYNAMIC = "",
        .SDL_LIBTHAI_DYNAMIC = "",
        .SDL_XKBCOMMON_VERSION_MAJOR = "",
        .SDL_XKBCOMMON_VERSION_MINOR = "",
        .SDL_XKBCOMMON_VERSION_PATCH = "",
        .SDL_IPHONE_KEYBOARD = false,
        .SDL_IPHONE_LAUNCHSCREEN = false,
        .SDL_EMSCRIPTEN_PERSISTENT_PATH_STRING = "",
    });
}
