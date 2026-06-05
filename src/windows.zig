const std = @import("std");
const build_zon = @import("../build.zig.zon");
const sources = @import("sdl.zon");
const root = @import("../build.zig");
const Subsystems = root.Subsystems;
const AllDrivers = root.Drivers;

pub fn build(
    b: *std.Build,
    target: std.Target,
    lib: *std.Build.Step.Compile,
    build_config_h: *std.Build.Step.ConfigHeader,
) void {
    _ = target;

    const upstream = b.dependency("sdl", .{});

    // Add the platform specific dependency include paths
    lib.root_module.addIncludePath(b.dependency("egl", .{}).path("api"));
    lib.root_module.addIncludePath(b.dependency("opengl", .{}).path("api"));

    // Link with the platform specific system libraries
    lib.root_module.linkSystemLibrary("advapi32", .{});
    lib.root_module.linkSystemLibrary("gdi32", .{});
    lib.root_module.linkSystemLibrary("imm32", .{});
    lib.root_module.linkSystemLibrary("kernel32", .{});
    lib.root_module.linkSystemLibrary("ole32", .{});
    lib.root_module.linkSystemLibrary("oleaut32", .{});
    lib.root_module.linkSystemLibrary("setupapi", .{});
    lib.root_module.linkSystemLibrary("shell32", .{});
    lib.root_module.linkSystemLibrary("user32", .{});
    lib.root_module.linkSystemLibrary("uuid", .{});
    lib.root_module.linkSystemLibrary("version", .{});
    lib.root_module.linkSystemLibrary("winmm", .{});

    // Add the platform specific sources
    lib.root_module.addCSourceFiles(.{
        .files = &sources.windows,
        .root = upstream.path("src"),
        .flags = root.flags,
    });

    if (lib.linkage == .dynamic) {
        lib.root_module.addWin32ResourceFile(.{ .file = upstream.path("src/core/windows/version.rc") });
    }

    // Set the platform specific build config
    build_config_h.addValues(.{
        .HAVE_GCC_ATOMICS = 1,

        .HAVE_DDRAW_H = 1,
        .HAVE_DINPUT_H = 1,
        .HAVE_DSOUND_H = 1,
        .HAVE_DXGI_H = 1,
        .HAVE_XINPUT_H = 1,
        .HAVE_DXGI1_5_H = 1,
        .HAVE_DXGI1_6_H = 1,

        .HAVE_MMDEVICEAPI_H = 1,
        .HAVE_TPCSHRD_H = 1,

        .HAVE_LIBC = 1,

        // Useful headers
        .HAVE_FLOAT_H = 1,
        .HAVE_LIMITS_H = 1,
        .HAVE_MATH_H = 1,
        .HAVE_SIGNAL_H = 1,
        .HAVE_STDARG_H = 1,
        .HAVE_STDDEF_H = 1,
        .HAVE_STDIO_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_WCHAR_H = 1,

        // C library functions
        .HAVE_MALLOC = 1,
        .HAVE_ABS = 1,
        .HAVE_MEMSET = 1,
        .HAVE_MEMCPY = 1,
        .HAVE_MEMMOVE = 1,
        .HAVE_MEMCMP = 1,
        .HAVE_STRLEN = 1,
        .HAVE__STRREV = 1,
        .HAVE_STRCHR = 1,
        .HAVE_STRRCHR = 1,
        .HAVE_STRSTR = 1,
        .HAVE_STRTOL = 1,
        .HAVE_STRTOUL = 1,
        .HAVE_STRTOD = 1,
        .HAVE_ATOI = 1,
        .HAVE_ATOF = 1,
        .HAVE_STRCMP = 1,
        .HAVE_STRNCMP = 1,
        .HAVE_STRPBRK = 1,
        .HAVE_VSSCANF = 1,
        .HAVE_VSNPRINTF = 1,
        .HAVE_ACOS = 1,
        .HAVE_ASIN = 1,
        .HAVE_ATAN = 1,
        .HAVE_ATAN2 = 1,
        .HAVE_CEIL = 1,
        .HAVE_COS = 1,
        .HAVE_EXP = 1,
        .HAVE_FABS = 1,
        .HAVE_FLOOR = 1,
        .HAVE_FMOD = 1,
        .HAVE_ISINF = 1,
        .HAVE_ISINF_FLOAT_MACRO = 1,
        .HAVE_ISNAN = 1,
        .HAVE_ISNAN_FLOAT_MACRO = 1,
        .HAVE_LOG = 1,
        .HAVE_LOG10 = 1,
        .HAVE_POW = 1,
        .HAVE_SIN = 1,
        .HAVE_SQRT = 1,
        .HAVE_TAN = 1,
        .HAVE_ACOSF = 1,
        .HAVE_ASINF = 1,
        .HAVE_ATANF = 1,
        .HAVE_ATAN2F = 1,
        .HAVE_CEILF = 1,
        .HAVE__COPYSIGN = 1,
        .HAVE_COSF = 1,
        .HAVE_EXPF = 1,
        .HAVE_FABSF = 1,
        .HAVE_FLOORF = 1,
        .HAVE_FMODF = 1,
        .HAVE_LOGF = 1,
        .HAVE_LOG10F = 1,
        .HAVE_POWF = 1,
        .HAVE_SINF = 1,
        .HAVE_SQRTF = 1,
        .HAVE_TANF = 1,
        .HAVE_STRTOLL = 1,
        .HAVE_STRTOULL = 1,
        .HAVE_LROUND = 1,
        .HAVE_LROUNDF = 1,
        .HAVE_ROUND = 1,
        .HAVE_ROUNDF = 1,
        .HAVE_SCALBN = 1,
        .HAVE_SCALBNF = 1,
        .HAVE_TRUNC = 1,
        .HAVE_TRUNCF = 1,
        .HAVE__FSEEKI64 = 1,

        // Enable various audio drivers
        .SDL_AUDIO_DRIVER_WASAPI = 1,
        .SDL_AUDIO_DRIVER_DSOUND = 1,
        .SDL_AUDIO_DRIVER_DUMMY = 1,

        // Enable various input drivers
        .SDL_JOYSTICK_DINPUT = 1,
        .SDL_JOYSTICK_HIDAPI = 1,
        .SDL_JOYSTICK_RAWINPUT = 1,
        .SDL_JOYSTICK_VIRTUAL = 1,
        .SDL_JOYSTICK_XINPUT = 1,
        .SDL_HAPTIC_DINPUT = 1,

        // Enable various process implementations
        .SDL_PROCESS_WINDOWS = 1,

        // Enable the sensor driver
        .SDL_SENSOR_WINDOWS = 1,

        // Enable various shared object loading systems
        .SDL_LOADSO_WINDOWS = 1,

        // Enable various threading systems
        .SDL_THREAD_GENERIC_COND_SUFFIX = 1,
        .SDL_THREAD_GENERIC_RWLOCK_SUFFIX = 1,
        .SDL_THREAD_WINDOWS = 1,

        // Enable RTC system
        .SDL_TIME_WINDOWS = 1,

        // Enable various timer systems
        .SDL_TIMER_WINDOWS = 1,

        // Enable various video drivers
        .SDL_VIDEO_DRIVER_DUMMY = 1,
        .SDL_VIDEO_DRIVER_WINDOWS = 1,

        .SDL_VIDEO_RENDER_D3D = 1,
        .SDL_VIDEO_RENDER_D3D11 = 1,
        .SDL_VIDEO_RENDER_D3D12 = 1,
        .SDL_VIDEO_RENDER_GPU = 1,

        // Enable OpenGL support
        .SDL_VIDEO_OPENGL = 1,
        .SDL_VIDEO_OPENGL_WGL = 1,
        .SDL_VIDEO_RENDER_OGL = 1,
        .SDL_VIDEO_RENDER_OGL_ES2 = 1,
        .SDL_VIDEO_OPENGL_ES2 = 1,
        .SDL_VIDEO_OPENGL_EGL = 1,

        // Enable Vulkan support
        .SDL_VIDEO_VULKAN = 1,
        .SDL_VIDEO_RENDER_VULKAN = 1,

        // Enable GPU support
        .SDL_GPU_D3D11 = 1,
        .SDL_GPU_D3D12 = 1,

        // Enable system power support
        .SDL_POWER_WINDOWS = 1,

        // Enable filesystem support
        .SDL_FILESYSTEM_WINDOWS = 1,
        .SDL_FSOPS_WINDOWS = 1,

        // Enable the camera driver
        .SDL_CAMERA_DRIVER_MEDIAFOUNDATION = 1,
        .SDL_CAMERA_DRIVER_DUMMY = 1,

        // Enable Steam storage
        .SDL_STORAGE_STEAM = 1,

        // Supporting these input drivers requires the winrt headers when cross compiling, which is
        // a bit annoying for cross compilation as Microsoft doesn't make the license on these very
        // clear. In practice they don't seem to do too much that they other input drivers don't
        // already do.
        .HAVE_WINDOWS_GAMING_INPUT_H = 0,
        .HAVE_GAMEINPUT_H = 0,

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
