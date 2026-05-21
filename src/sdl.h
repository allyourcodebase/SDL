//! # SDL Headers
//!
//! This file provides headers for tranlsation by Translate C to generate a Zig module.
//!
//! Usage of this file is optional. If you need additional configuration, consider using the static
//! library directly, or providing your own type definitions (e.g. by running Translate C yourself.)
//!
//! # Rationale
//!
//! Most SDL headers are provided by `SDL.h`, either directly or transitively. If this covered all
//! functionality, we would simplify translate `SDL.h`. However, `SDL.h` leaves off some files.
//!
//! We could expose these additional headers via build options, but this would require excessive
//! build configuration that would need to be kept in sync across dependencies that use the SDL
//! package.
//!
//! Alternatively we could provide a separate Zig module for each additional header, but this would
//! result in duplicated symbols across the modules since these headers include headers already
//! provided by `SDL3/SDL.h`.
//!
//! These headers are not particularly large, and Zig modules are lazily evaluated anyway, so we've
//! opted to just include everything here except where otherwise noted in "Skipped Headers."
//!
//! # Skipped Headers
//!
//! The following includes are *not* provided for the given reasons:
//!
//! `SDL3/SDL_opengles` is a very old fixed function version of OpenGL ES from 2003. We would
//! need to supply `GLES/gl.h` ourselves for this to work. It is very unlikely that new code is
//! depending on OpenGL ES1, if you need it I recommend calling Translate C yourself and providing
//! `GLES/gl.h` yourself.
//!
//! `SDL3/SDL_main.h` is not provided since its functionality is only usable from C/C++, and the
//! goal of this file is to generate a Zig module.
//!
//! If you find that any other headers are missing, file an issue. They should either be added, or
//! the reason for their absence should be documented here. Note that headers not included directly
//! by `SDL.h` may be included transitively.

// Include the main SDL header, this header provides most other SDL headers.
#include <SDL3/SDL.h>

// This is not pulling in the full Vulkan API to every build. It's just pulling in a few functions
// that can be called to load the API and integrate with SDL.
#include <SDL3/SDL_vulkan.h>

// These headers provide OpenGL, EGL, ES2, and related functionality for windowing system
// integration. These do generate a number of function headers and typedefs that aren't necessary
// when not using these APIs, but they are properly namespaced and Zig's lazy evaluation should take
// care of them when unused.
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_egl.h>
#include <SDL3/SDL_opengles2.h>
