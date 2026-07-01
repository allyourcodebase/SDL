[![CI](https://github.com/Games-By-Mason/sdl_zig/actions/workflows/ci.yaml/badge.svg)](https://github.com/Games-By-Mason/sdl_zig/actions)

# SDL Zig

SDL3 ported to the Zig build system.

Supports cross compilation and custom platform configuration.

# Versioning

See `build.zig.zon` for the current Zig version, see releases for support for previous Zig versions.

The versions specified in `build.zig.zon` are split between the package version (before the plus) and the SDL version (after the plus). For example, version `1.0.0+3.4.4` is package version 1.0.0 with support for SDL 3.4.4.

# Setup

You can add SDL3 to your project like this by updating `build.zig.zon` from the command line:
```sh
zig fetch --save <url-of-this-repo>
```

And then you can add it to your `build.zig` like this:
```zig
const sdl = b.dependency("sdl", .{
    .optimize = optimize,
    .target = target,
});
exe.root_module.addImport("sdl3", sdl.module("sdl3"));
```

Finally, you can use SDL's C API from Zig like this:
```zig
const std = @import("std");
const sdl = @import("sdl3");
if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
    std.debug.panic("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
}
defer sdl.SDL_Quit();
```

## Example

You can run `src/example.zig` from the command line:
```sh
zig build run-example
```

This should produce a window with a pulsing gradient.

## Help, `SDL_Init` failed on Linux!

```sh
SDL_Init failed: No available video device
```

By default, [SDL loads most of its dependencies at runtime on Linux.](https://wiki.libsdl.org/SDL3/README-linux) This lets it decide at runtime which audio drivers to use, whether to use Wayland or X11, etc.

For this to work, the libraries SDL is looking for need to be on your `LD_LIBRARY_PATH`. This may not be the case by default on distributions like NixOS.

Here's a `shell.nix` for a Vulkan app as an example of running an SDL application on NixOS with either X11 or Wayland.
```
{ pkgs ? import <nixpkgs> {}}:

pkgs.mkShell {
  packages = with pkgs; [
    vulkan-validation-layers
  ];
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
    alsa-lib
    libdecor
    libusb1
    libxkbcommon
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libXext
    xorg.libXi
    udev
  ]);
}
```

Not all of these dependencies in this example are required. Since both X11 and Wayland dependencies are listed, SDL will use its judgement to decide which to prefer unless `SDL_VIDEODRIVER` is set.

# Target Configuration

This library provides a default configuration for common targets:
* [x] Linux (including Steam Deck)
  * [x] Steam Deck
* [x] Windows
* [x] macOS (no cross compilation due to Apple licensing)
* [ ] [Emscripten (help wanted!)](https://github.com/allyourcodebase/SDL3/issues/5)
* [ ] [Consoles (help wanted!)](https://github.com/allyourcodebase/SDL3/issues/6)

You can override the default target configuration by setting `default_target_config` to `false`, and then providing your own configuration. This is typically only necessary when your platform doesn't yet have a default configuration:
```zig
const sdl = b.dependency("sdl", .{
    .optimize = optimize,
    .target = target,
    .default_target_config = false,
});
const sdl_lib = sdl.artifact("SDL3");
sdl_lib.addIncludePath(...); // Path to your `SDL_build_config.h`, see `windows.zig` for an example of generating this
```

Any other necessary tweaks such as turning of linking with libc, linking with dependencies, or adding other headers can be done here as well.

If you're interested in adding default configuration for additional targets, listed or not, contributions are welcome! See [src/linux.zig](src/linux.zig) or [src/windows.zig](src/windows.zig) for examples of how this works.

When making a PR that adds support for a new target:
* Replicate the [default SDL configuration for the target](https://github.com/libsdl-org/SDL/tree/main/include/build_config) within reason
* Pull dependencies in via the build system rather than vendoring them when possible. If this isn't possible, vendor the needed files in `/deps` with a README explaining why they couldn't be pulled in via the build system and any relevant licensing information.
* Cross compilation to all targets should be possible within reason unless forbidden by licensing.
* Update [.github/workflows/ci.yaml](.github/workflows/ci.yaml) to test the new target.

# Updating Dependencies

## SDL

* Modify `build.zig.zon` to point to the desired SDL version
* If you get linker errors or missing headers relating to Wayland protocols on Linux, new Wayland protocols were added upstream. You can fix this by running `zig build wayland-scanner` with `wayland-scanner`.
* If you get any other linker errors or missing files, sources were added or renamed upstream, and you need to update `src/sdl.zon`.
* Check if any headers need to be added to to `src/sdl.h`, or alternatively, if the intentional absence of any headers from this file needs to be documented.

## SDL's Dependencies

This should rarely be necessary. When it is, you can update their version in `build.zig.zon` if present, and any relevant files in `/deps` if present.
