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
    const upstream = b.dependency("sdl", .{});

    // Provide the platform specific dependency include paths
    {
        // Set up the config include write file step
        const generated = b.addWriteFiles();
        lib.root_module.addIncludePath(generated.getDirectory());

        // Provide the D-Bus headers
        {
            const dbus = b.dependency("dbus", .{});
            lib.root_module.addIncludePath(dbus.path("."));

            const version_string = build_zon.dependencies.dbus.version;
            const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;
            std.debug.assert(target.cTypeByteSize(.short) == 2);
            std.debug.assert(target.cTypeByteSize(.int) == 4);
            const dbus_config = b.addConfigHeader(
                .{
                    .style = .{ .autoconf_at = dbus.path("dbus/dbus-arch-deps.h.in") },
                    .include_path = "dbus/dbus-arch-deps.h",
                },
                .{
                    .DBUS_INT32_TYPE = "int",
                    .DBUS_INT16_TYPE = "short",
                    .DBUS_SIZEOF_VOID_P = target.ptrBitWidth() / 8,

                    .DBUS_MAJOR_VERSION = @as(i64, version.major),
                    .DBUS_MINOR_VERSION = @as(i64, version.minor),
                    .DBUS_MICRO_VERSION = @as(i64, version.patch),
                    .DBUS_VERSION = version_string,
                },
            );
            _ = generated.addCopyFile(
                dbus_config.getOutputFile(),
                dbus_config.include_path,
            );

            if (target.cTypeByteSize(.int) == 2) {
                dbus_config.addValues(.{
                    .DBUS_INT16_TYPE = "int",
                });
            } else if (target.cTypeByteSize(.short) == 2) {
                dbus_config.addValues(.{
                    .DBUS_INT16_TYPE = "short",
                });
            } else {
                @panic("Could not find a 16-bit integer type");
            }

            if (target.cTypeByteSize(.int) == 4) {
                dbus_config.addValues(.{
                    .DBUS_INT32_TYPE = "int",
                });
            } else if (target.cTypeByteSize(.long) == 4) {
                dbus_config.addValues(.{
                    .DBUS_INT32_TYPE = "long",
                });
            } else if (target.cTypeByteSize(.longlong) == 4) {
                dbus_config.addValues(.{
                    .DBUS_INT32_TYPE = "long long",
                });
            } else {
                @panic("Could not find a 32-bit integer type");
            }

            if (target.cTypeByteSize(.int) == 8) {
                dbus_config.addValues(.{
                    .DBUS_INT64_TYPE = "int",
                    .DBUS_INT64_CONSTANT = "(val)",
                    .DBUS_UINT64_CONSTANT = "(val##U)",
                    .DBUS_INT64_MODIFIER = "",
                });
            } else if (target.cTypeByteSize(.long) == 8) {
                dbus_config.addValues(.{
                    .DBUS_INT64_TYPE = "long",
                    .DBUS_INT64_CONSTANT = "(val##L)",
                    .DBUS_UINT64_CONSTANT = "(val##UL)",
                    .DBUS_INT64_MODIFIER = "l",
                });
            } else if (target.cTypeByteSize(.longlong) == 8) {
                dbus_config.addValues(.{
                    .DBUS_INT64_TYPE = "long long",
                    .DBUS_INT64_CONSTANT = "(val##LL)",
                    .DBUS_UINT64_CONSTANT = "(val##ULL)",
                    .DBUS_INT64_MODIFIER = "ll",
                });
            } else {
                @panic("Could not find a 64-bit integer type");
            }
        }

        // Provide the IBus headers
        {
            // The headers are here
            lib.root_module.addIncludePath(b.dependency("ibus", .{}).path("src"));

            // They depend on the GLib headers, which require some configuration
            lib.root_module.addIncludePath(b.path("deps/glib/upstream/include"));
            lib.root_module.addIncludePath(b.path("deps/glib/upstream/include/glib"));
            lib.root_module.addIncludePath(b.path("deps/glib/upstream/include/gmodule"));
            lib.root_module.addIncludePath(b.path("deps/glib/cached/include"));
            lib.root_module.addIncludePath(b.path("deps/glib/cached/include/glib"));
            lib.root_module.addIncludePath(b.path("deps/glib/cached/include/gmodule"));

            const glib_config = b.addConfigHeader(.{
                .style = .{ .cmake = b.path("deps/glib/glibconfig.h.in") },
                .include_path = "glibconfig.h",
            }, .{});
            _ = generated.addCopyFile(glib_config.getOutputFile(), glib_config.include_path);

            // Configure glib
            {
                // Defines
                const version_string = @import("../deps/glib/info.zon").version;
                const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;
                glib_config.addValues(.{
                    .GLIB_HAVE_ALLOCA_H = 1,
                    .GLIB_USING_SYSTEM_PRINTF = 1,
                    // Shows up as empty instead of 0, but never referenced anyway
                    .G_HAVE_GROWING_STACK = "0",
                    .G_ATOMIC_LOCK_FREE = 1,
                    .G_HAVE_FREE_SIZED = 1,
                    .GLIB_MAJOR_VERSION = @as(i64, version.major),
                    .GLIB_MINOR_VERSION = @as(i64, version.minor),
                    .GLIB_MICRO_VERSION = @as(i64, version.patch),
                    // Always the same on Linux
                    .g_dir_separator = "/",
                    .g_searchpath_separator = ":",
                    .g_pid_type = "int",
                    .g_pid_format = "i",
                    .g_module_suffix = "so",
                    // These are hard coded in the meson build
                    .g_pollin = "1",
                    .g_pollout = "4",
                    .g_pollpri = "2",
                    .g_pollhup = "16",
                    .g_pollerr = "8",
                    .g_pollnval = "32",
                    // These are the values I got when building form source. I would expect them to be
                    // the same for all Linux targets, but I'm not actually sure how they were
                    // generated.
                    .g_af_unix = "1",
                    .g_af_inet = "2",
                    .g_af_inet6 = "10",
                    .g_msg_oob = "1",
                    .g_msg_peek = "2",
                    .g_msg_dontroute = "4",
                });

                // Integer sizes
                std.debug.assert(target.cTypeByteSize(.short) == 2);
                std.debug.assert(target.cTypeByteSize(.int) == 4);
                glib_config.addValues(.{
                    .gint16 = "short",
                    .gint16_modifier = "h",
                    .gint16_format = "hi",
                    .guint16_format = "hu",
                    .gint32 = "int",
                    .gint32_modifier = "",
                    .gint32_format = "i",
                    .guint32_format = "u",
                });
                if (target.cTypeByteSize(.int) == 8) {
                    glib_config.addValues(.{
                        .glib_extension = "",
                        .gint64 = "int",
                        .gint64_constant = "(val)",
                        .guint64_constant = "(val##U)",
                        .gint64_modifier = "",
                        .gint64_format = "i",
                        .guint64_format = "u",
                    });
                } else if (target.cTypeByteSize(.long) == 8) {
                    glib_config.addValues(.{
                        .glib_extension = "",
                        .gint64 = "long",
                        .gint64_constant = "(val##L)",
                        .guint64_constant = "(val##UL)",
                        .gint64_modifier = "l",
                        .gint64_format = "li",
                        .guint64_format = "lu",
                    });
                } else if (target.cTypeByteSize(.longlong) == 8) {
                    glib_config.addValues(.{
                        .glib_extension = "",
                        .gint64 = "long long",
                        .gint64_constant = "(val##LL)",
                        .guint64_constant = "(val##ULL)",
                        .gint64_modifier = "ll",
                        .gint64_format = "lli",
                        .guint64_format = "llu",
                    });
                } else {
                    @panic("Could not find a 64-bit integer type");
                }
                if (target.cTypeBitSize(.int) == target.ptrBitWidth()) {
                    glib_config.addValues(.{
                        .glib_size_type_define = "int",
                        .gsize_modifier = "u",
                        .gssize_modifier = "",
                        .gsize_format = "u",
                        .gssize_format = "i",
                        .glib_msize_type = "INT",
                        .g_pollfd_format = "%i",
                        .glib_gpi_cast = "(gint)",
                        .glib_gpui_cast = "(guint)",
                        .glib_intptr_type_define = "int",
                        .gintptr_modifier = "",
                        .gintptr_format = "i",
                        .guintptr_format = "u",
                    });
                } else if (target.cTypeBitSize(.long) == target.ptrBitWidth()) {
                    glib_config.addValues(.{
                        .glib_size_type_define = "long",
                        .gsize_modifier = "l",
                        .gssize_modifier = "l",
                        .gsize_format = "lu",
                        .gssize_format = "li",
                        .glib_msize_type = "LONG",
                        .g_pollfd_format = "%d",
                        .glib_gpi_cast = "(glong)",
                        .glib_gpui_cast = "(gulong)",
                        .glib_intptr_type_define = "long",
                        .gintptr_modifier = "l",
                        .gintptr_format = "li",
                        .guintptr_format = "lu",
                    });
                } else {
                    // Upstream doesn't have required typedefs for long long so that's not an option
                    @panic("Could not find a pointer sized integer type");
                }
                glib_config.addValues(.{
                    .glib_void_p = target.ptrBitWidth() / 8,
                    .glib_long = target.cTypeByteSize(.long),
                    .glib_size_t = target.ptrBitWidth() / 8,
                    .glib_ssize_t = target.ptrBitWidth() / 8,
                });

                // Endianness
                const endianness = std.Target.Cpu.Arch.endian(target.cpu.arch);
                glib_config.addValues(.{
                    .glib_os = "#define G_OS_UNIX",
                    .glib_vacopy = "#define G_VA_COPY_AS_ARRAY 1",
                    .g_threads_impl_def = "POSIX",
                    .g_bs_native = switch (endianness) {
                        .little => "LE",
                        .big => "BE",
                    },
                    .g_bs_alien = switch (endianness) {
                        .little => "BE",
                        .big => "LE",
                    },
                    .glongbits = target.cTypeBitSize(.long),
                    .gintbits = target.cTypeBitSize(.int),
                    .gsizebits = target.ptrBitWidth(),
                    .g_byte_order = switch (endianness) {
                        .little => "G_LITTLE_ENDIAN",
                        .big => "G_BIG_ENDIAN",
                    },
                });
            }

            const version_h = b.addConfigHeader(.{
                .style = .{
                    .autoconf_at = b.path("deps/glib/upstream/include/glib/gversionmacros.h.in"),
                },
                .include_path = "glib/gversionmacros.h",
            }, .{
                .GLIB_VERSIONS = @embedFile("../deps/glib/glib_versions.h"),
            });
            _ = generated.addCopyFile(version_h.getOutputFile(), version_h.include_path);

            lib.root_module.addIncludePath(b.path("deps/glib/include"));
        }

        // Provide the X11 headers
        {
            {
                const x11 = b.dependency("x11", .{});

                lib.root_module.addIncludePath(x11.path("include"));

                const config = b.addConfigHeader(.{
                    .style = .{ .autoconf_undef = x11.path("include/X11/XlibConf.h.in") },
                    .include_path = "X11/XlibConf.h",
                }, .{
                    .XTHREADS = 1,
                    .XUSE_MTSAFE_API = 1,
                });
                _ = generated.addCopyFile(config.getOutputFile(), config.include_path);
            }

            // Provide the Xcursor headers
            {
                const xcursor = b.dependency("xcursor", .{});
                const version_string = build_zon.dependencies.xcursor.version;
                const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;
                const config = b.addConfigHeader(.{
                    .style = .{ .autoconf_undef = xcursor.path("include/X11/Xcursor/Xcursor.h.in") },
                    .include_path = "X11/Xcursor/Xcursor.h",
                }, .{
                    .XCURSOR_LIB_MAJOR = @as(i64, version.major),
                    .XCURSOR_LIB_MINOR = @as(i64, version.minor),
                    .XCURSOR_LIB_REVISION = @as(i64, version.patch),
                });
                _ = generated.addCopyFile(config.getOutputFile(), config.include_path);
            }
        }

        // Provide the liburing headers
        {
            lib.root_module.addIncludePath(b.path("deps/liburing/include"));
            const compat_h = b.addConfigHeader(.{
                .style = .{ .autoconf_undef = b.path("deps/liburing/compat.h.in") },
                .include_path = "liburing/compat.h",
            }, .{
                // Recent kernels should always have these features, so they're hard coded to `1`
                // for now, but this can be made more flexible in the future if needed.
                .HAS_KERNEL_RWF_T = 1,
                .HAS_KERNEL_TIMESPEC = 1,
                .HAS_OPENAT_2 = 1,
                .HAS_SYS_STAT = 1,
                .HAS_FUTEX_WAITV = 1,
                .HAS_IDTYPE_T = 1,
            });
            _ = generated.addCopyFile(compat_h.getOutputFile(), compat_h.include_path);

            const version_string = build_zon.dependencies.decor.version;
            const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;
            const version_h = b.addConfigHeader(.{
                .style = .{ .autoconf_undef = b.path("deps/liburing/io_uring_version.h.in") },
                .include_path = "liburing/io_uring_version.h",
            }, .{
                .IO_URING_VERSION_MAJOR = @as(i64, version.major),
                .IO_URING_VERSION_MINOR = @as(i64, version.minor),
            });
            _ = generated.addCopyFile(version_h.getOutputFile(), version_h.include_path);
        }

        // Provide the pipewire headers
        {
            const pipewire = b.dependency("pipewire", .{});
            lib.root_module.addIncludePath(pipewire.path("spa/include"));
            lib.root_module.addIncludePath(pipewire.path("src"));
            const version_string = build_zon.dependencies.pipewire.version;
            const api_version_string = build_zon.dependencies.pipewire.api_version;
            const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;
            const config_h = b.addConfigHeader(.{
                .style = .{ .autoconf_at = pipewire.path("src/pipewire/version.h.in") },
                .include_path = "pipewire/version.h",
            }, .{
                .PIPEWIRE_VERSION_MAJOR = @as(i64, version.major),
                .PIPEWIRE_VERSION_MINOR = @as(i64, version.minor),
                .PIPEWIRE_VERSION_MICRO = @as(i64, version.patch),
                .PIPEWIRE_API_VERSION = api_version_string,
            });
            _ = generated.addCopyFile(config_h.getOutputFile(), config_h.include_path);
        }

        // Provide the pulseaudio headers
        {
            @setEvalBranchQuota(2000);
            // Workaround for cross compilation, see comment in `build.zig.zon`
            const pulseaudio_name = switch (@import("builtin").os.tag) {
                .windows => "pulseaudio_windows",
                else => "pulseaudio",
            };
            if (b.lazyDependency(pulseaudio_name, .{})) |pulseaudio| {
                lib.root_module.addIncludePath(pulseaudio.path("src"));
                const version_string = build_zon.dependencies.pulseaudio.version;
                const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;
                const api_version_string = build_zon.dependencies.pulseaudio.api_version;
                const api_version = comptime std.fmt.parseInt(u32, api_version_string, 10) catch unreachable;
                const protocol_version_string = build_zon.dependencies.pulseaudio.protocol_version;
                const protocol_version = comptime std.fmt.parseInt(u32, protocol_version_string, 10) catch unreachable;
                const version_h = b.addConfigHeader(.{
                    .style = .{ .cmake = pulseaudio.path("src/pulse/version.h.in") },
                    .include_path = "pulse/version.h",
                }, .{
                    .PA_MAJOR = @as(i64, version.major),
                    .PA_MINOR = @as(i64, version.minor),
                    .PA_API_VERSION = api_version,
                    .PA_PROTOCOL_VERSION = protocol_version,
                });
                _ = generated.addCopyFile(version_h.getOutputFile(), version_h.include_path);
            }
        }

        // Provide the Wayland headers
        {
            const wayland = b.dependency("wayland", .{});
            lib.root_module.addIncludePath(wayland.path("src"));
            lib.root_module.addIncludePath(wayland.path("cursor"));
            lib.root_module.addIncludePath(wayland.path("egl"));

            // Provide the config header
            const version_string = build_zon.dependencies.wayland.version;
            const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;
            const version_h = b.addConfigHeader(.{
                .style = .{ .cmake = wayland.path("src/wayland-version.h.in") },
                .include_path = "wayland-version.h",
            }, .{
                .WAYLAND_VERSION_MAJOR = @as(i64, version.major),
                .WAYLAND_VERSION_MINOR = @as(i64, version.minor),
                .WAYLAND_VERSION_MICRO = @as(i64, version.patch),
                .WAYLAND_VERSION = version_string,
            });
            _ = generated.addCopyFile(version_h.getOutputFile(), version_h.include_path);
        }

        // Provide the Direct Rendering Manager headers
        {
            lib.root_module.addIncludePath(b.path("deps/drm/include"));
            lib.root_module.addIncludePath(b.path("deps/drm/include/drm"));
            lib.root_module.addIncludePath(b.path("deps/mesa/include/gbm"));
        }

        // Provide the Alsa headers
        {
            const alsa = b.dependency("alsa", .{});
            _ = generated.addCopyDirectory(alsa.path("include"), "alsa", .{
                .include_extensions = &.{".h"},
            });
            lib.root_module.addIncludePath(generated.getDirectory());
            lib.root_module.addIncludePath(b.path("deps/alsa/include"));
        }

        // Provide the Fribidi headers
        {
            const fribidi = b.dependency("fribidi", .{});
            const interface_version = build_zon.dependencies.fribidi.interface_version;
            const version_string = build_zon.dependencies.fribidi.version;
            const version = comptime std.SemanticVersion.parse(version_string) catch unreachable;

            const unicode_version_string = build_zon.dependencies.fribidi.unicode_version;
            const unicode_version = comptime std.SemanticVersion.parse(unicode_version_string) catch unreachable;

            const fribidi_config_path = "fribidi-config.h";
            const version_h = b.addConfigHeader(.{
                .style = .{ .cmake = fribidi.path("lib/fribidi-config.h.in") },
                .include_path = fribidi_config_path,
            }, .{
                .configure_input = fribidi_config_path,

                .PACKAGE = "fribidi",
                .PACKAGE_NAME = "GNU FriBidi",
                .PACKAGE_BUGREPORT = "https://github.com/fribidi/fribidi/issues/new",

                .FRIBIDI_VERSION = version_string,
                .FRIBIDI_MAJOR_VERSION = @as(i64, version.major),
                .FRIBIDI_MINOR_VERSION = @as(i64, version.minor),
                .FRIBIDI_MICRO_VERSION = @as(i64, version.patch),
                .FRIBIDI_INTERFACE_VERSION = interface_version,

                .SIZEOF_INT = target.cTypeByteSize(.int),

                .FRIBIDI_MSVC_BUILD_PLACEHOLDER = "",
            });
            _ = generated.addCopyFile(version_h.getOutputFile(), version_h.include_path);

            const unicode_version_h = b.addConfigHeader(.{
                .style = .blank,
                .include_path = "fribidi-unicode-version.h",
            }, .{
                .FRIBIDI_UNICODE_VERSION = unicode_version_string,
                .FRIBIDI_UNICODE_MAJOR_VERSION = @as(i64, unicode_version.major),
                .FRIBIDI_UNICODE_MINOR_VERSION = @as(i64, unicode_version.minor),
                .FRIBIDI_UNICODE_MICRO_VERSION = @as(i64, unicode_version.patch),
            });
            _ = generated.addCopyFile(unicode_version_h.getOutputFile(), unicode_version_h.include_path);

            lib.root_module.addIncludePath(fribidi.path("lib"));
        }

        // Provide upstream headers that don't require any special handling
        lib.root_module.addIncludePath(b.dependency("egl", .{}).path("api"));
        lib.root_module.addIncludePath(b.dependency("opengl", .{}).path("api"));
        lib.root_module.addIncludePath(b.dependency("xkbcommon", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("xorgproto", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("xext", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("usb", .{}).path("libusb"));
        lib.root_module.addIncludePath(b.dependency("xi", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("xfixes", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("xrandr", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("xrender", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("xscrnsaver", .{}).path("include"));
        lib.root_module.addIncludePath(b.dependency("jack", .{}).path("common"));
        lib.root_module.addIncludePath(b.dependency("sndio", .{}).path("libsndio"));
        lib.root_module.addIncludePath(b.path("deps/wayland/protocols"));
        lib.root_module.addIncludePath(b.dependency("decor", .{}).path("src"));
        lib.root_module.addIncludePath(b.path("deps/mesa/include"));
        lib.root_module.addIncludePath(b.dependency("thai", .{}).path("include"));

        // Provide vendored headers that don't require any special handling
        lib.root_module.addIncludePath(b.path("deps/xcb/include"));
        lib.root_module.addIncludePath(b.path("deps/udev/include"));
    }

    // Add the platform specific SDL sources
    lib.root_module.addCSourceFiles(.{
        .files = &(sources.unix ++ sources.linux ++ sources.x11 ++ sources.pthread),
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
    const libdecor_version_string = build_zon.dependencies.decor.version;
    const libdecor_version = comptime std.SemanticVersion.parse(libdecor_version_string) catch unreachable;
    const xkbcommon_version_string = build_zon.dependencies.xkbcommon.version;
    const xkbcommon_version = comptime std.SemanticVersion.parse(xkbcommon_version_string) catch unreachable;
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
        .SDL_XKBCOMMON_VERSION_MAJOR = @as(i64, xkbcommon_version.major),
        .SDL_XKBCOMMON_VERSION_MINOR = @as(i64, xkbcommon_version.minor),
        .SDL_XKBCOMMON_VERSION_PATCH = @as(i64, xkbcommon_version.patch),

        // Set the libdecor version
        .SDL_LIBDECOR_VERSION_MAJOR = @as(i64, libdecor_version.major),
        .SDL_LIBDECOR_VERSION_MINOR = @as(i64, libdecor_version.minor),
        .SDL_LIBDECOR_VERSION_PATCH = @as(i64, libdecor_version.patch),

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

fn formatDynamic(comptime name: []const u8) []const u8 {
    return std.fmt.comptimePrint("\"{s}\"", .{name});
}
