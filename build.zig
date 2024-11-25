const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = target.result;

    const is_shared_library = t.isAndroid();
    const lib = if (!is_shared_library) b.addStaticLibrary(.{
        .name = "SDL2",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) else b.addSharedLibrary(.{
        .name = "SDL2",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const sdl_include_path = b.path("include");
    lib.addCSourceFiles(.{ .files = &generic_src_files });
    lib.defineCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", "1");
    lib.linkLibC();
    switch (t.os.tag) {
        .windows => {
            lib.defineCMacro("SDL_STATIC_LIB", "");
            lib.addCSourceFiles(.{ .files = &windows_src_files });
            lib.linkSystemLibrary("user32");
            lib.linkSystemLibrary("shell32");
            lib.linkSystemLibrary("advapi32");
            lib.linkSystemLibrary("setupapi");
            lib.linkSystemLibrary("winmm");
            lib.linkSystemLibrary("gdi32");
            lib.linkSystemLibrary("imm32");
            lib.linkSystemLibrary("version");
            lib.linkSystemLibrary("oleaut32");
            lib.linkSystemLibrary("ole32");
        },
        .macos => {
            lib.addCSourceFiles(.{ .files = &darwin_src_files });
            lib.addCSourceFiles(.{
                .files = &objective_c_src_files,
                .flags = &.{"-fobjc-arc"},
            });
            lib.linkFramework("OpenGL");
            lib.linkFramework("Metal");
            lib.linkFramework("CoreVideo");
            lib.linkFramework("Cocoa");
            lib.linkFramework("IOKit");
            lib.linkFramework("ForceFeedback");
            lib.linkFramework("Carbon");
            lib.linkFramework("CoreAudio");
            lib.linkFramework("AudioToolbox");
            lib.linkFramework("AVFoundation");
            lib.linkFramework("Foundation");
        },
        .emscripten => {
            lib.defineCMacro("__EMSCRIPTEN_PTHREADS__ ", "1");
            lib.defineCMacro("USE_SDL", "2");
            lib.addCSourceFiles(.{ .files = &emscripten_src_files });
            if (b.sysroot == null) {
                @panic("Pass '--sysroot \"$EMSDK/upstream/emscripten\"'");
            }

            const cache_include = std.fs.path.join(b.allocator, &.{ b.sysroot.?, "cache", "sysroot", "include" }) catch @panic("Out of memory");
            defer b.allocator.free(cache_include);

            var dir = std.fs.openDirAbsolute(cache_include, std.fs.Dir.OpenDirOptions{ .access_sub_paths = true, .no_follow = true }) catch @panic("No emscripten cache. Generate it!");
            dir.close();

            lib.addIncludePath(.{ .cwd_relative = cache_include });
        },
        else => {
            if (t.isAndroid()) {
                lib.root_module.addCSourceFiles(.{
                    .files = &android_src_files,
                });

                // This is needed for "src/render/opengles/SDL_render_gles.c" to compile
                lib.root_module.addCMacro("GL_GLEXT_PROTOTYPES", "1");

                // Add Java files to dependency so that they can be copied downstream
                const java_dir = b.path("android-project/app/src/main/java/org/libsdl/app");
                const java_files: []const []const u8 = &.{
                    "SDL.java",
                    "SDLSurface.java",
                    "SDLActivity.java",
                    "SDLAudioManager.java",
                    "SDLControllerManager.java",
                    "HIDDevice.java",
                    "HIDDeviceUSB.java",
                    "HIDDeviceManager.java",
                    "HIDDeviceBLESteamController.java",
                };
                const java_write_files = b.addNamedWriteFiles("sdljava");
                for (java_files) |java_file_basename| {
                    _ = java_write_files.addCopyFile(java_dir.path(b, java_file_basename), java_file_basename);
                }

                // https://github.com/libsdl-org/SDL/blob/release-2.30.6/Android.mk#L82C62-L82C69
                lib.linkSystemLibrary("dl");
                lib.linkSystemLibrary("GLESv1_CM");
                lib.linkSystemLibrary("GLESv2");
                lib.linkSystemLibrary("OpenSLES");
                lib.linkSystemLibrary("log");
                lib.linkSystemLibrary("android");
            }
        },
    }

    lib.addIncludePath(sdl_include_path);

    const use_pregenerated_config = switch (t.os.tag) {
        .windows, .macos, .emscripten => true,
        .linux => t.isAndroid(),
        else => false,
    };

    if (use_pregenerated_config) {
        lib.addIncludePath(b.path("include-pregen"));
        lib.installHeadersDirectory(b.path("include-pregen"), "SDL2", .{});
        lib.addCSourceFiles(.{ .files = render_driver_sw.src_files });
    } else {
        // causes pregenerated SDL_config.h to assert an error
        lib.defineCMacro("USING_GENERATED_CONFIG_H", "");

        var files = std.ArrayList([]const u8).init(b.allocator);
        defer files.deinit();

        const config_header = b.addConfigHeader(.{
            .style = .{ .cmake = b.path("include/SDL_config.h.cmake") },
            .include_path = "SDL_config.h",
        }, .{
            .HAVE_STDINT_H = 1,
            .HAVE_SYS_TYPES_H = 1,
            .HAVE_STDIO_H = 1,
            .HAVE_STRING_H = 1,
            .HAVE_ALLOCA_H = 1,
            .HAVE_CTYPE_H = 1,
            .HAVE_FLOAT_H = 1,
            .HAVE_ICONV_H = 1,
            .HAVE_INTTYPES_H = 1,
            .HAVE_LIMITS_H = 1,
            .HAVE_MALLOC_H = 1,
            .HAVE_MATH_H = 1,
            .HAVE_MEMORY_H = 1,
            .HAVE_SIGNAL_H = 1,
            .HAVE_STDARG_H = 1,
            .HAVE_STDDEF_H = 1,
            .HAVE_STDLIB_H = 1,
            .HAVE_STRINGS_H = 1,
            .HAVE_WCHAR_H = 1,
            .HAVE_LIBUNWIND_H = 1,
            .HAVE_LIBC = 1,
            .STDC_HEADERS = 1,
            .SDL_DEFAULT_ASSERT_LEVEL_CONFIGURED = 0,
        });
        switch (t.os.tag) {
            .linux => {
                files.appendSlice(&linux_src_files) catch @panic("OOM");
                config_header.addValues(.{
                    .HAVE_INOTIFY = 1,
                    .HAVE_INOTIFY_INIT = 1,
                    .HAVE_INOTIFY_INIT1 = 1,
                    .HAVE_LINUX_INPUT_H = 1,
                    .SDL_FILESYSTEM_UNIX = 1,
                    .SDL_HAPTIC_LINUX = 1,
                    .SDL_INPUT_LINUXEV = 1,
                    .SDL_JOYSTICK_LINUX = 1,
                    .SDL_LOADSO_DLOPEN = 1,
                    .SDL_THREAD_PTHREAD = 1,
                    .SDL_THREAD_PTHREAD_RECURSIVE_MUTEX = 1,
                    .SDL_TIMER_UNIX = 1,
                    .SDL_VIDEO_OPENGL = 1,
                    .SDL_VIDEO_OPENGL_ES = 1,
                    .SDL_VIDEO_OPENGL_ES2 = 1,
                    .SDL_VIDEO_OPENGL_BGL = 1,
                    .SDL_VIDEO_OPENGL_CGL = 1,
                    .SDL_VIDEO_OPENGL_GLX = 1,
                    .SDL_VIDEO_OPENGL_WGL = 1,
                    .SDL_VIDEO_OPENGL_EGL = 1,
                    .SDL_VIDEO_OPENGL_OSMESA = 1,
                    .SDL_VIDEO_OPENGL_OSMESA_DYNAMIC = 1,
                });
                applyOptions(b, lib, &files, config_header, &linux_options);
            },
            else => {},
        }
        lib.addCSourceFiles(.{ .files = files.toOwnedSlice() catch @panic("OOM") });
        lib.addConfigHeader(config_header);
        lib.installHeader(config_header.getOutput(), "SDL2/SDL_config.h");

        const revision_header = b.addConfigHeader(.{
            .style = .{ .cmake = b.path("include/SDL_revision.h.cmake") },
            .include_path = "SDL_revision.h",
        }, .{
            .SDL_VENDOR_INFO = "allyourcodebase.com",
        });
        lib.addConfigHeader(revision_header);
        lib.installHeader(revision_header.getOutput(), "SDL2/SDL_revision.h");
    }

    const use_hidapi = b.option(bool, "use_hidapi", "Use hidapi shared library") orelse t.isAndroid();

    if (use_hidapi) {
        const hidapi_lib = b.addSharedLibrary(.{
            .name = "hidapi",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        hidapi_lib.addIncludePath(sdl_include_path);
        hidapi_lib.addIncludePath(b.path("include-pregen"));
        hidapi_lib.root_module.addCSourceFiles(.{
            .root = b.path(""),
            .files = &[_][]const u8{
                "src/hidapi/android/hid.cpp",
            },
            .flags = &.{"-std=c++11"},
        });
        hidapi_lib.linkSystemLibrary("log");
        hidapi_lib.linkLibCpp();
        lib.linkLibrary(hidapi_lib);
        b.installArtifact(hidapi_lib);
    }

    lib.installHeadersDirectory(b.path("include"), "SDL2", .{});
    b.installArtifact(lib);
}

const generic_src_files = [_][]const u8{
    "src/SDL.c",
    "src/SDL_assert.c",
    "src/SDL_dataqueue.c",
    "src/SDL_error.c",
    "src/SDL_guid.c",
    "src/SDL_hints.c",
    "src/SDL_list.c",
    "src/SDL_log.c",
    "src/SDL_utils.c",
    "src/atomic/SDL_atomic.c",
    "src/atomic/SDL_spinlock.c",
    "src/audio/SDL_audio.c",
    "src/audio/SDL_audiocvt.c",
    "src/audio/SDL_audiodev.c",
    "src/audio/SDL_audiotypecvt.c",
    "src/audio/SDL_mixer.c",
    "src/audio/SDL_wave.c",
    "src/cpuinfo/SDL_cpuinfo.c",
    "src/dynapi/SDL_dynapi.c",
    "src/events/SDL_clipboardevents.c",
    "src/events/SDL_displayevents.c",
    "src/events/SDL_dropevents.c",
    "src/events/SDL_events.c",
    "src/events/SDL_gesture.c",
    "src/events/SDL_keyboard.c",
    "src/events/SDL_keysym_to_scancode.c",
    "src/events/SDL_mouse.c",
    "src/events/SDL_quit.c",
    "src/events/SDL_scancode_tables.c",
    "src/events/SDL_touch.c",
    "src/events/SDL_windowevents.c",
    "src/events/imKStoUCS.c",
    "src/file/SDL_rwops.c",
    "src/haptic/SDL_haptic.c",
    "src/hidapi/SDL_hidapi.c",

    "src/joystick/SDL_gamecontroller.c",
    "src/joystick/SDL_joystick.c",
    "src/joystick/SDL_steam_virtual_gamepad.c",
    "src/joystick/controller_type.c",
    "src/joystick/virtual/SDL_virtualjoystick.c",

    "src/libm/e_atan2.c",
    "src/libm/e_exp.c",
    "src/libm/e_fmod.c",
    "src/libm/e_log.c",
    "src/libm/e_log10.c",
    "src/libm/e_pow.c",
    "src/libm/e_rem_pio2.c",
    "src/libm/e_sqrt.c",
    "src/libm/k_cos.c",
    "src/libm/k_rem_pio2.c",
    "src/libm/k_sin.c",
    "src/libm/k_tan.c",
    "src/libm/s_atan.c",
    "src/libm/s_copysign.c",
    "src/libm/s_cos.c",
    "src/libm/s_fabs.c",
    "src/libm/s_floor.c",
    "src/libm/s_scalbn.c",
    "src/libm/s_sin.c",
    "src/libm/s_tan.c",
    "src/locale/SDL_locale.c",
    "src/misc/SDL_url.c",
    "src/power/SDL_power.c",
    "src/render/SDL_d3dmath.c",
    "src/render/SDL_render.c",
    "src/render/SDL_yuv_sw.c",
    "src/sensor/SDL_sensor.c",
    "src/stdlib/SDL_crc16.c",
    "src/stdlib/SDL_crc32.c",
    "src/stdlib/SDL_getenv.c",
    "src/stdlib/SDL_iconv.c",
    "src/stdlib/SDL_malloc.c",
    "src/stdlib/SDL_mslibc.c",
    "src/stdlib/SDL_qsort.c",
    "src/stdlib/SDL_stdlib.c",
    "src/stdlib/SDL_string.c",
    "src/stdlib/SDL_strtokr.c",
    "src/thread/SDL_thread.c",
    "src/timer/SDL_timer.c",
    "src/video/SDL_RLEaccel.c",
    "src/video/SDL_blit.c",
    "src/video/SDL_blit_0.c",
    "src/video/SDL_blit_1.c",
    "src/video/SDL_blit_A.c",
    "src/video/SDL_blit_N.c",
    "src/video/SDL_blit_auto.c",
    "src/video/SDL_blit_copy.c",
    "src/video/SDL_blit_slow.c",
    "src/video/SDL_bmp.c",
    "src/video/SDL_clipboard.c",
    "src/video/SDL_egl.c",
    "src/video/SDL_fillrect.c",
    "src/video/SDL_pixels.c",
    "src/video/SDL_rect.c",
    "src/video/SDL_shape.c",
    "src/video/SDL_stretch.c",
    "src/video/SDL_surface.c",
    "src/video/SDL_video.c",
    "src/video/SDL_vulkan_utils.c",
    "src/video/SDL_yuv.c",
    "src/video/yuv2rgb/yuv_rgb_lsx.c",
    "src/video/yuv2rgb/yuv_rgb_sse.c",
    "src/video/yuv2rgb/yuv_rgb_std.c",

    "src/video/dummy/SDL_nullevents.c",
    "src/video/dummy/SDL_nullframebuffer.c",
    "src/video/dummy/SDL_nullvideo.c",

    "src/audio/dummy/SDL_dummyaudio.c",

    "src/joystick/hidapi/SDL_hidapi_combined.c",
    "src/joystick/hidapi/SDL_hidapi_gamecube.c",
    "src/joystick/hidapi/SDL_hidapi_luna.c",
    "src/joystick/hidapi/SDL_hidapi_ps3.c",
    "src/joystick/hidapi/SDL_hidapi_ps4.c",
    "src/joystick/hidapi/SDL_hidapi_ps5.c",
    "src/joystick/hidapi/SDL_hidapi_rumble.c",
    "src/joystick/hidapi/SDL_hidapi_shield.c",
    "src/joystick/hidapi/SDL_hidapi_stadia.c",
    "src/joystick/hidapi/SDL_hidapi_steam.c",
    "src/joystick/hidapi/SDL_hidapi_steamdeck.c",
    "src/joystick/hidapi/SDL_hidapi_switch.c",
    "src/joystick/hidapi/SDL_hidapi_wii.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360w.c",
    "src/joystick/hidapi/SDL_hidapi_xboxone.c",
    "src/joystick/hidapi/SDL_hidapijoystick.c",
};

const android_src_files = [_][]const u8{
    "src/core/android/SDL_android.c",

    "src/audio/android/SDL_androidaudio.c",
    "src/audio/openslES/SDL_openslES.c",
    "src/audio/aaudio/SDL_aaudio.c",

    "src/haptic/android/SDL_syshaptic.c",
    "src/joystick/android/SDL_sysjoystick.c",
    "src/locale/android/SDL_syslocale.c",
    "src/misc/android/SDL_sysurl.c",
    "src/power/android/SDL_syspower.c",
    "src/filesystem/android/SDL_sysfilesystem.c",
    "src/sensor/android/SDL_androidsensor.c",

    "src/timer/unix/SDL_systimer.c",
    "src/loadso/dlopen/SDL_sysloadso.c",

    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
    "src/render/opengles/SDL_render_gles.c",
    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",

    "src/video/android/SDL_androidclipboard.c",
    "src/video/android/SDL_androidevents.c",
    "src/video/android/SDL_androidgl.c",
    "src/video/android/SDL_androidkeyboard.c",
    "src/video/android/SDL_androidmessagebox.c",
    "src/video/android/SDL_androidmouse.c",
    "src/video/android/SDL_androidtouch.c",
    "src/video/android/SDL_androidvideo.c",
    "src/video/android/SDL_androidvulkan.c",
    "src/video/android/SDL_androidwindow.c",
};

const windows_src_files = [_][]const u8{
    "src/core/windows/SDL_hid.c",
    "src/core/windows/SDL_immdevice.c",
    "src/core/windows/SDL_windows.c",
    "src/core/windows/SDL_xinput.c",
    "src/filesystem/windows/SDL_sysfilesystem.c",
    "src/haptic/windows/SDL_dinputhaptic.c",
    "src/haptic/windows/SDL_windowshaptic.c",
    "src/haptic/windows/SDL_xinputhaptic.c",
    "src/hidapi/windows/hid.c",
    "src/joystick/windows/SDL_dinputjoystick.c",
    "src/joystick/windows/SDL_rawinputjoystick.c",
    "src/joystick/windows/SDL_windows_gaming_input.c",
    "src/joystick/windows/SDL_windowsjoystick.c",
    "src/joystick/windows/SDL_xinputjoystick.c",

    "src/loadso/windows/SDL_sysloadso.c",
    "src/locale/windows/SDL_syslocale.c",
    "src/main/windows/SDL_windows_main.c",
    "src/misc/windows/SDL_sysurl.c",
    "src/power/windows/SDL_syspower.c",
    "src/sensor/windows/SDL_windowssensor.c",
    "src/timer/windows/SDL_systimer.c",
    "src/video/windows/SDL_windowsclipboard.c",
    "src/video/windows/SDL_windowsevents.c",
    "src/video/windows/SDL_windowsframebuffer.c",
    "src/video/windows/SDL_windowskeyboard.c",
    "src/video/windows/SDL_windowsmessagebox.c",
    "src/video/windows/SDL_windowsmodes.c",
    "src/video/windows/SDL_windowsmouse.c",
    "src/video/windows/SDL_windowsopengl.c",
    "src/video/windows/SDL_windowsopengles.c",
    "src/video/windows/SDL_windowsshape.c",
    "src/video/windows/SDL_windowsvideo.c",
    "src/video/windows/SDL_windowsvulkan.c",
    "src/video/windows/SDL_windowswindow.c",

    "src/thread/windows/SDL_syscond_cv.c",
    "src/thread/windows/SDL_sysmutex.c",
    "src/thread/windows/SDL_syssem.c",
    "src/thread/windows/SDL_systhread.c",
    "src/thread/windows/SDL_systls.c",
    "src/thread/generic/SDL_syscond.c",

    "src/render/direct3d/SDL_render_d3d.c",
    "src/render/direct3d/SDL_shaders_d3d.c",
    "src/render/direct3d11/SDL_render_d3d11.c",
    "src/render/direct3d11/SDL_shaders_d3d11.c",
    "src/render/direct3d12/SDL_render_d3d12.c",
    "src/render/direct3d12/SDL_shaders_d3d12.c",

    "src/audio/directsound/SDL_directsound.c",
    "src/audio/wasapi/SDL_wasapi.c",
    "src/audio/wasapi/SDL_wasapi_win32.c",
    "src/audio/winmm/SDL_winmm.c",
    "src/audio/disk/SDL_diskaudio.c",

    "src/render/opengl/SDL_render_gl.c",
    "src/render/opengl/SDL_shaders_gl.c",
    "src/render/opengles/SDL_render_gles.c",
    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",
};

const linux_src_files = [_][]const u8{
    "src/core/linux/SDL_evdev.c",
    "src/core/linux/SDL_evdev_capabilities.c",
    "src/core/linux/SDL_evdev_kbd.c",
    "src/core/linux/SDL_threadprio.c",
    "src/core/unix/SDL_poll.c",

    "src/filesystem/unix/SDL_sysfilesystem.c",

    "src/haptic/linux/SDL_syshaptic.c",

    "src/loadso/dlopen/SDL_sysloadso.c",
    "src/joystick/linux/SDL_sysjoystick.c",
    "src/joystick/steam/SDL_steamcontroller.c",

    "src/misc/unix/SDL_sysurl.c",

    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",

    "src/timer/unix/SDL_systimer.c",

    "src/video/x11/SDL_x11clipboard.c",
    "src/video/x11/SDL_x11dyn.c",
    "src/video/x11/SDL_x11events.c",
    "src/video/x11/SDL_x11framebuffer.c",
    "src/video/x11/SDL_x11keyboard.c",
    "src/video/x11/SDL_x11messagebox.c",
    "src/video/x11/SDL_x11modes.c",
    "src/video/x11/SDL_x11mouse.c",
    "src/video/x11/SDL_x11opengl.c",
    "src/video/x11/SDL_x11opengles.c",
    "src/video/x11/SDL_x11shape.c",
    "src/video/x11/SDL_x11touch.c",
    "src/video/x11/SDL_x11video.c",
    "src/video/x11/SDL_x11vulkan.c",
    "src/video/x11/SDL_x11window.c",
    "src/video/x11/SDL_x11xfixes.c",
    "src/video/x11/SDL_x11xinput2.c",
    "src/video/x11/edid-parse.c",
};

const darwin_src_files = [_][]const u8{
    "src/haptic/darwin/SDL_syshaptic.c",
    "src/joystick/darwin/SDL_iokitjoystick.c",
    "src/power/macosx/SDL_syspower.c",
    "src/timer/unix/SDL_systimer.c",
    "src/loadso/dlopen/SDL_sysloadso.c",
    "src/audio/disk/SDL_diskaudio.c",
    "src/render/opengl/SDL_render_gl.c",
    "src/render/opengl/SDL_shaders_gl.c",
    "src/render/opengles/SDL_render_gles.c",
    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",
    "src/sensor/dummy/SDL_dummysensor.c",

    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
};

const objective_c_src_files = [_][]const u8{
    "src/audio/coreaudio/SDL_coreaudio.m",
    "src/file/cocoa/SDL_rwopsbundlesupport.m",
    "src/filesystem/cocoa/SDL_sysfilesystem.m",
    //"src/hidapi/testgui/mac_support_cocoa.m",
    // This appears to be for SDL3 only.
    //"src/joystick/apple/SDL_mfijoystick.m",
    "src/locale/macosx/SDL_syslocale.m",
    "src/misc/macosx/SDL_sysurl.m",
    "src/power/uikit/SDL_syspower.m",
    "src/render/metal/SDL_render_metal.m",
    "src/sensor/coremotion/SDL_coremotionsensor.m",
    "src/video/cocoa/SDL_cocoaclipboard.m",
    "src/video/cocoa/SDL_cocoaevents.m",
    "src/video/cocoa/SDL_cocoakeyboard.m",
    "src/video/cocoa/SDL_cocoamessagebox.m",
    "src/video/cocoa/SDL_cocoametalview.m",
    "src/video/cocoa/SDL_cocoamodes.m",
    "src/video/cocoa/SDL_cocoamouse.m",
    "src/video/cocoa/SDL_cocoaopengl.m",
    "src/video/cocoa/SDL_cocoaopengles.m",
    "src/video/cocoa/SDL_cocoashape.m",
    "src/video/cocoa/SDL_cocoavideo.m",
    "src/video/cocoa/SDL_cocoavulkan.m",
    "src/video/cocoa/SDL_cocoawindow.m",
    "src/video/uikit/SDL_uikitappdelegate.m",
    "src/video/uikit/SDL_uikitclipboard.m",
    "src/video/uikit/SDL_uikitevents.m",
    "src/video/uikit/SDL_uikitmessagebox.m",
    "src/video/uikit/SDL_uikitmetalview.m",
    "src/video/uikit/SDL_uikitmodes.m",
    "src/video/uikit/SDL_uikitopengles.m",
    "src/video/uikit/SDL_uikitopenglview.m",
    "src/video/uikit/SDL_uikitvideo.m",
    "src/video/uikit/SDL_uikitview.m",
    "src/video/uikit/SDL_uikitviewcontroller.m",
    "src/video/uikit/SDL_uikitvulkan.m",
    "src/video/uikit/SDL_uikitwindow.m",
};

const ios_src_files = [_][]const u8{
    "src/hidapi/ios/hid.m",
    "src/misc/ios/SDL_sysurl.m",
    "src/joystick/iphoneos/SDL_mfijoystick.m",
};

const emscripten_src_files = [_][]const u8{
    "src/audio/emscripten/SDL_emscriptenaudio.c",
    "src/filesystem/emscripten/SDL_sysfilesystem.c",
    "src/joystick/emscripten/SDL_sysjoystick.c",
    "src/locale/emscripten/SDL_syslocale.c",
    "src/misc/emscripten/SDL_sysurl.c",
    "src/power/emscripten/SDL_syspower.c",
    "src/video/emscripten/SDL_emscriptenevents.c",
    "src/video/emscripten/SDL_emscriptenframebuffer.c",
    "src/video/emscripten/SDL_emscriptenmouse.c",
    "src/video/emscripten/SDL_emscriptenopengles.c",
    "src/video/emscripten/SDL_emscriptenvideo.c",

    "src/timer/unix/SDL_systimer.c",
    "src/loadso/dlopen/SDL_sysloadso.c",
    "src/audio/disk/SDL_diskaudio.c",
    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",
    "src/sensor/dummy/SDL_dummysensor.c",

    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
};

const unknown_src_files = [_][]const u8{
    "src/thread/generic/SDL_syscond.c",
    "src/thread/generic/SDL_sysmutex.c",
    "src/thread/generic/SDL_syssem.c",
    "src/thread/generic/SDL_systhread.c",
    "src/thread/generic/SDL_systls.c",

    "src/audio/aaudio/SDL_aaudio.c",
    "src/audio/android/SDL_androidaudio.c",
    "src/audio/arts/SDL_artsaudio.c",
    "src/audio/dsp/SDL_dspaudio.c",
    "src/audio/esd/SDL_esdaudio.c",
    "src/audio/fusionsound/SDL_fsaudio.c",
    "src/audio/n3ds/SDL_n3dsaudio.c",
    "src/audio/nacl/SDL_naclaudio.c",
    "src/audio/nas/SDL_nasaudio.c",
    "src/audio/netbsd/SDL_netbsdaudio.c",
    "src/audio/openslES/SDL_openslES.c",
    "src/audio/os2/SDL_os2audio.c",
    "src/audio/paudio/SDL_paudio.c",
    "src/audio/pipewire/SDL_pipewire.c",
    "src/audio/ps2/SDL_ps2audio.c",
    "src/audio/psp/SDL_pspaudio.c",
    "src/audio/qsa/SDL_qsa_audio.c",
    "src/audio/sndio/SDL_sndioaudio.c",
    "src/audio/sun/SDL_sunaudio.c",
    "src/audio/vita/SDL_vitaaudio.c",

    "src/core/android/SDL_android.c",
    "src/core/freebsd/SDL_evdev_kbd_freebsd.c",
    "src/core/openbsd/SDL_wscons_kbd.c",
    "src/core/openbsd/SDL_wscons_mouse.c",
    "src/core/os2/SDL_os2.c",
    "src/core/os2/geniconv/geniconv.c",
    "src/core/os2/geniconv/os2cp.c",
    "src/core/os2/geniconv/os2iconv.c",
    "src/core/os2/geniconv/sys2utf8.c",
    "src/core/os2/geniconv/test.c",

    "src/file/n3ds/SDL_rwopsromfs.c",

    "src/filesystem/android/SDL_sysfilesystem.c",
    "src/filesystem/dummy/SDL_sysfilesystem.c",
    "src/filesystem/n3ds/SDL_sysfilesystem.c",
    "src/filesystem/nacl/SDL_sysfilesystem.c",
    "src/filesystem/os2/SDL_sysfilesystem.c",
    "src/filesystem/ps2/SDL_sysfilesystem.c",
    "src/filesystem/psp/SDL_sysfilesystem.c",
    "src/filesystem/riscos/SDL_sysfilesystem.c",
    "src/filesystem/unix/SDL_sysfilesystem.c",
    "src/filesystem/vita/SDL_sysfilesystem.c",

    "src/haptic/android/SDL_syshaptic.c",
    "src/haptic/dummy/SDL_syshaptic.c",

    "src/hidapi/libusb/hid.c",
    "src/hidapi/mac/hid.c",

    "src/joystick/android/SDL_sysjoystick.c",
    "src/joystick/bsd/SDL_bsdjoystick.c",
    "src/joystick/dummy/SDL_sysjoystick.c",
    "src/joystick/n3ds/SDL_sysjoystick.c",
    "src/joystick/os2/SDL_os2joystick.c",
    "src/joystick/ps2/SDL_sysjoystick.c",
    "src/joystick/psp/SDL_sysjoystick.c",
    "src/joystick/vita/SDL_sysjoystick.c",

    "src/loadso/dummy/SDL_sysloadso.c",
    "src/loadso/os2/SDL_sysloadso.c",

    "src/locale/android/SDL_syslocale.c",
    "src/locale/dummy/SDL_syslocale.c",
    "src/locale/n3ds/SDL_syslocale.c",
    "src/locale/unix/SDL_syslocale.c",
    "src/locale/vita/SDL_syslocale.c",
    "src/locale/winrt/SDL_syslocale.c",

    "src/main/android/SDL_android_main.c",
    "src/main/dummy/SDL_dummy_main.c",
    "src/main/gdk/SDL_gdk_main.c",
    "src/main/n3ds/SDL_n3ds_main.c",
    "src/main/nacl/SDL_nacl_main.c",
    "src/main/ps2/SDL_ps2_main.c",
    "src/main/psp/SDL_psp_main.c",
    "src/main/uikit/SDL_uikit_main.c",

    "src/misc/android/SDL_sysurl.c",
    "src/misc/dummy/SDL_sysurl.c",
    "src/misc/riscos/SDL_sysurl.c",
    "src/misc/unix/SDL_sysurl.c",
    "src/misc/vita/SDL_sysurl.c",

    "src/power/android/SDL_syspower.c",
    "src/power/haiku/SDL_syspower.c",
    "src/power/n3ds/SDL_syspower.c",
    "src/power/psp/SDL_syspower.c",
    "src/power/vita/SDL_syspower.c",

    "src/sensor/android/SDL_androidsensor.c",
    "src/sensor/n3ds/SDL_n3dssensor.c",
    "src/sensor/vita/SDL_vitasensor.c",

    "src/test/SDL_test_assert.c",
    "src/test/SDL_test_common.c",
    "src/test/SDL_test_compare.c",
    "src/test/SDL_test_crc32.c",
    "src/test/SDL_test_font.c",
    "src/test/SDL_test_fuzzer.c",
    "src/test/SDL_test_harness.c",
    "src/test/SDL_test_imageBlit.c",
    "src/test/SDL_test_imageBlitBlend.c",
    "src/test/SDL_test_imageFace.c",
    "src/test/SDL_test_imagePrimitives.c",
    "src/test/SDL_test_imagePrimitivesBlend.c",
    "src/test/SDL_test_log.c",
    "src/test/SDL_test_md5.c",
    "src/test/SDL_test_memory.c",
    "src/test/SDL_test_random.c",

    "src/thread/n3ds/SDL_syscond.c",
    "src/thread/n3ds/SDL_sysmutex.c",
    "src/thread/n3ds/SDL_syssem.c",
    "src/thread/n3ds/SDL_systhread.c",
    "src/thread/os2/SDL_sysmutex.c",
    "src/thread/os2/SDL_syssem.c",
    "src/thread/os2/SDL_systhread.c",
    "src/thread/os2/SDL_systls.c",
    "src/thread/ps2/SDL_syssem.c",
    "src/thread/ps2/SDL_systhread.c",
    "src/thread/psp/SDL_sysmutex.c",
    "src/thread/psp/SDL_syssem.c",
    "src/thread/psp/SDL_systhread.c",
    "src/thread/vita/SDL_sysmutex.c",
    "src/thread/vita/SDL_syssem.c",
    "src/thread/vita/SDL_systhread.c",

    "src/timer/dummy/SDL_systimer.c",
    "src/timer/haiku/SDL_systimer.c",
    "src/timer/n3ds/SDL_systimer.c",
    "src/timer/os2/SDL_systimer.c",
    "src/timer/ps2/SDL_systimer.c",
    "src/timer/psp/SDL_systimer.c",
    "src/timer/vita/SDL_systimer.c",

    "src/video/android/SDL_androidclipboard.c",
    "src/video/android/SDL_androidevents.c",
    "src/video/android/SDL_androidgl.c",
    "src/video/android/SDL_androidkeyboard.c",
    "src/video/android/SDL_androidmessagebox.c",
    "src/video/android/SDL_androidmouse.c",
    "src/video/android/SDL_androidtouch.c",
    "src/video/android/SDL_androidvideo.c",
    "src/video/android/SDL_androidvulkan.c",
    "src/video/android/SDL_androidwindow.c",
    "src/video/directfb/SDL_DirectFB_WM.c",
    "src/video/directfb/SDL_DirectFB_dyn.c",
    "src/video/directfb/SDL_DirectFB_events.c",
    "src/video/directfb/SDL_DirectFB_modes.c",
    "src/video/directfb/SDL_DirectFB_mouse.c",
    "src/video/directfb/SDL_DirectFB_opengl.c",
    "src/video/directfb/SDL_DirectFB_render.c",
    "src/video/directfb/SDL_DirectFB_shape.c",
    "src/video/directfb/SDL_DirectFB_video.c",
    "src/video/directfb/SDL_DirectFB_vulkan.c",
    "src/video/directfb/SDL_DirectFB_window.c",
    "src/video/kmsdrm/SDL_kmsdrmdyn.c",
    "src/video/kmsdrm/SDL_kmsdrmevents.c",
    "src/video/kmsdrm/SDL_kmsdrmmouse.c",
    "src/video/kmsdrm/SDL_kmsdrmopengles.c",
    "src/video/kmsdrm/SDL_kmsdrmvideo.c",
    "src/video/kmsdrm/SDL_kmsdrmvulkan.c",
    "src/video/n3ds/SDL_n3dsevents.c",
    "src/video/n3ds/SDL_n3dsframebuffer.c",
    "src/video/n3ds/SDL_n3dsswkb.c",
    "src/video/n3ds/SDL_n3dstouch.c",
    "src/video/n3ds/SDL_n3dsvideo.c",
    "src/video/nacl/SDL_naclevents.c",
    "src/video/nacl/SDL_naclglue.c",
    "src/video/nacl/SDL_naclopengles.c",
    "src/video/nacl/SDL_naclvideo.c",
    "src/video/nacl/SDL_naclwindow.c",
    "src/video/offscreen/SDL_offscreenevents.c",
    "src/video/offscreen/SDL_offscreenframebuffer.c",
    "src/video/offscreen/SDL_offscreenopengles.c",
    "src/video/offscreen/SDL_offscreenvideo.c",
    "src/video/offscreen/SDL_offscreenwindow.c",
    "src/video/os2/SDL_os2dive.c",
    "src/video/os2/SDL_os2messagebox.c",
    "src/video/os2/SDL_os2mouse.c",
    "src/video/os2/SDL_os2util.c",
    "src/video/os2/SDL_os2video.c",
    "src/video/os2/SDL_os2vman.c",
    "src/video/pandora/SDL_pandora.c",
    "src/video/pandora/SDL_pandora_events.c",
    "src/video/ps2/SDL_ps2video.c",
    "src/video/psp/SDL_pspevents.c",
    "src/video/psp/SDL_pspgl.c",
    "src/video/psp/SDL_pspmouse.c",
    "src/video/psp/SDL_pspvideo.c",
    "src/video/qnx/gl.c",
    "src/video/qnx/keyboard.c",
    "src/video/qnx/video.c",
    "src/video/raspberry/SDL_rpievents.c",
    "src/video/raspberry/SDL_rpimouse.c",
    "src/video/raspberry/SDL_rpiopengles.c",
    "src/video/raspberry/SDL_rpivideo.c",
    "src/video/riscos/SDL_riscosevents.c",
    "src/video/riscos/SDL_riscosframebuffer.c",
    "src/video/riscos/SDL_riscosmessagebox.c",
    "src/video/riscos/SDL_riscosmodes.c",
    "src/video/riscos/SDL_riscosmouse.c",
    "src/video/riscos/SDL_riscosvideo.c",
    "src/video/riscos/SDL_riscoswindow.c",
    "src/video/vita/SDL_vitaframebuffer.c",
    "src/video/vita/SDL_vitagl_pvr.c",
    "src/video/vita/SDL_vitagles.c",
    "src/video/vita/SDL_vitagles_pvr.c",
    "src/video/vita/SDL_vitakeyboard.c",
    "src/video/vita/SDL_vitamessagebox.c",
    "src/video/vita/SDL_vitamouse.c",
    "src/video/vita/SDL_vitatouch.c",
    "src/video/vita/SDL_vitavideo.c",
    "src/video/vivante/SDL_vivanteopengles.c",
    "src/video/vivante/SDL_vivanteplatform.c",
    "src/video/vivante/SDL_vivantevideo.c",
    "src/video/vivante/SDL_vivantevulkan.c",

    "src/render/opengl/SDL_render_gl.c",
    "src/render/opengl/SDL_shaders_gl.c",
    "src/render/opengles/SDL_render_gles.c",
    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",
    "src/render/ps2/SDL_render_ps2.c",
    "src/render/psp/SDL_render_psp.c",
    "src/render/vitagxm/SDL_render_vita_gxm.c",
    "src/render/vitagxm/SDL_render_vita_gxm_memory.c",
    "src/render/vitagxm/SDL_render_vita_gxm_tools.c",
};

const static_headers = [_][]const u8{
    "begin_code.h",
    "close_code.h",
    "SDL_assert.h",
    "SDL_atomic.h",
    "SDL_audio.h",
    "SDL_bits.h",
    "SDL_blendmode.h",
    "SDL_clipboard.h",
    "SDL_config_android.h",
    "SDL_config_emscripten.h",
    "SDL_config_iphoneos.h",
    "SDL_config_macosx.h",
    "SDL_config_minimal.h",
    "SDL_config_ngage.h",
    "SDL_config_os2.h",
    "SDL_config_pandora.h",
    "SDL_config_windows.h",
    "SDL_config_wingdk.h",
    "SDL_config_winrt.h",
    "SDL_config_xbox.h",
    "SDL_copying.h",
    "SDL_cpuinfo.h",
    "SDL_egl.h",
    "SDL_endian.h",
    "SDL_error.h",
    "SDL_events.h",
    "SDL_filesystem.h",
    "SDL_gamecontroller.h",
    "SDL_gesture.h",
    "SDL_guid.h",
    "SDL.h",
    "SDL_haptic.h",
    "SDL_hidapi.h",
    "SDL_hints.h",
    "SDL_joystick.h",
    "SDL_keyboard.h",
    "SDL_keycode.h",
    "SDL_loadso.h",
    "SDL_locale.h",
    "SDL_log.h",
    "SDL_main.h",
    "SDL_messagebox.h",
    "SDL_metal.h",
    "SDL_misc.h",
    "SDL_mouse.h",
    "SDL_mutex.h",
    "SDL_name.h",
    "SDL_opengles2_gl2ext.h",
    "SDL_opengles2_gl2.h",
    "SDL_opengles2_gl2platform.h",
    "SDL_opengles2.h",
    "SDL_opengles2_khrplatform.h",
    "SDL_opengles.h",
    "SDL_opengl_glext.h",
    "SDL_opengl.h",
    "SDL_pixels.h",
    "SDL_platform.h",
    "SDL_power.h",
    "SDL_quit.h",
    "SDL_rect.h",
    "SDL_render.h",
    "SDL_rwops.h",
    "SDL_scancode.h",
    "SDL_sensor.h",
    "SDL_shape.h",
    "SDL_stdinc.h",
    "SDL_surface.h",
    "SDL_system.h",
    "SDL_syswm.h",
    "SDL_test_assert.h",
    "SDL_test_common.h",
    "SDL_test_compare.h",
    "SDL_test_crc32.h",
    "SDL_test_font.h",
    "SDL_test_fuzzer.h",
    "SDL_test.h",
    "SDL_test_harness.h",
    "SDL_test_images.h",
    "SDL_test_log.h",
    "SDL_test_md5.h",
    "SDL_test_memory.h",
    "SDL_test_random.h",
    "SDL_thread.h",
    "SDL_timer.h",
    "SDL_touch.h",
    "SDL_types.h",
    "SDL_version.h",
    "SDL_video.h",
    "SDL_vulkan.h",
};

const SdlOption = struct {
    name: []const u8,
    desc: []const u8,
    default: bool,
    // SDL configs affect the public SDL_config.h header file. Any values
    // should occur in a header file in the include directory.
    sdl_configs: []const []const u8,
    // C Macros are similar to SDL configs but aren't present in the public
    // headers and only affect the SDL implementation.  None of the values
    // should occur in the include directory.
    c_macros: []const []const u8 = &.{},
    src_files: []const []const u8,
    system_libs: []const []const u8,
};
const render_driver_sw = SdlOption{
    .name = "render_driver_software",
    .desc = "enable the software render driver",
    .default = true,
    .sdl_configs = &.{},
    .c_macros = &.{"SDL_VIDEO_RENDER_SW"},
    .src_files = &.{
        "src/render/software/SDL_blendfillrect.c",
        "src/render/software/SDL_blendline.c",
        "src/render/software/SDL_blendpoint.c",
        "src/render/software/SDL_drawline.c",
        "src/render/software/SDL_drawpoint.c",
        "src/render/software/SDL_render_sw.c",
        "src/render/software/SDL_rotate.c",
        "src/render/software/SDL_triangle.c",
    },
    .system_libs = &.{},
};
const linux_options = [_]SdlOption{
    render_driver_sw,
    .{
        .name = "video_driver_x11",
        .desc = "enable the x11 video driver",
        .default = true,
        .sdl_configs = &.{
            "SDL_VIDEO_DRIVER_X11",
            "SDL_VIDEO_DRIVER_X11_SUPPORTS_GENERIC_EVENTS",
        },
        .src_files = &.{},
        .system_libs = &.{ "X11", "Xext" },
    },
    .{
        .name = "render_driver_ogl",
        .desc = "enable the opengl render driver",
        .default = true,
        .sdl_configs = &.{"SDL_VIDEO_RENDER_OGL"},
        .src_files = &.{
            "src/render/opengl/SDL_render_gl.c",
            "src/render/opengl/SDL_shaders_gl.c",
        },
        .system_libs = &.{},
    },
    .{
        .name = "render_driver_ogl_es",
        .desc = "enable the opengl es render driver",
        .default = true,
        .sdl_configs = &.{"SDL_VIDEO_RENDER_OGL_ES"},
        .src_files = &.{
            "src/render/opengles/SDL_render_gles.c",
        },
        .system_libs = &.{},
    },
    .{
        .name = "render_driver_ogl_es2",
        .desc = "enable the opengl es2 render driver",
        .default = true,
        .sdl_configs = &.{"SDL_VIDEO_RENDER_OGL_ES2"},
        .src_files = &.{
            "src/render/opengles2/SDL_render_gles2.c",
            "src/render/opengles2/SDL_shaders_gles2.c",
        },
        .system_libs = &.{},
    },
    .{
        .name = "audio_driver_pulse",
        .desc = "enable the pulse audio driver",
        .default = true,
        .sdl_configs = &.{"SDL_AUDIO_DRIVER_PULSEAUDIO"},
        .src_files = &.{"src/audio/pulseaudio/SDL_pulseaudio.c"},
        .system_libs = &.{"pulse"},
    },
    .{
        .name = "audio_driver_alsa",
        .desc = "enable the alsa audio driver",
        .default = false,
        .sdl_configs = &.{"SDL_AUDIO_DRIVER_ALSA"},
        .src_files = &.{"src/audio/alsa/SDL_alsa_audio.c"},
        .system_libs = &.{"alsa"},
    },
};

fn applyOptions(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    files: *std.ArrayList([]const u8),
    config_header: *std.Build.Step.ConfigHeader,
    comptime options: []const SdlOption,
) void {
    inline for (options) |option| {
        const enabled = if (b.option(bool, option.name, option.desc)) |o| o else option.default;
        for (option.c_macros) |name| {
            lib.defineCMacro(name, if (enabled) "1" else "0");
        }
        for (option.sdl_configs) |config| {
            config_header.values.put(config, .{ .int = if (enabled) 1 else 0 }) catch @panic("OOM");
        }
        if (enabled) {
            files.appendSlice(option.src_files) catch @panic("OOM");
            for (option.system_libs) |lib_name| {
                lib.linkSystemLibrary(lib_name);
            }
        }
    }
}
