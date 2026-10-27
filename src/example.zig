const std = @import("std");
const builtin = @import("builtin");
const sdl = @import("sdl3");

// Zig 0.16's `std.Io.Threaded` fails to compile for Emscripten (`std.os.emscripten.W.STOPSIG` has
// the wrong return type), and it's referenced by default through `std.debug`'s I/O. Opt out of it
// there, which is why this example logs with `SDL_Log` rather than `std.debug.print`.
pub const std_options_debug_threaded_io: ?*std.Io.Threaded = if (builtin.os.tag == .emscripten)
    null
else
    std.Io.Threaded.global_single_threaded;
pub const std_options_debug_io: std.Io = if (builtin.os.tag == .emscripten)
    std.Io.failing
else
    std.Io.Threaded.global_single_threaded.io();

// `SDL_main.h` isn't part of the translated module (see `sdl.h`), so declare the entry point for
// the main callbacks ourselves. Using callbacks instead of a `while` loop lets platforms that own
// the main loop, such as Emscripten where blocking would freeze the browser tab, drive the app.
extern fn SDL_EnterAppMainCallbacks(
    argc: c_int,
    argv: ?[*]?[*:0]u8,
    appinit: sdl.SDL_AppInit_func,
    appiter: sdl.SDL_AppIterate_func,
    appevent: sdl.SDL_AppEvent_func,
    appquit: sdl.SDL_AppQuit_func,
) c_int;

var window: ?*sdl.SDL_Window = null;
var renderer: ?*sdl.SDL_Renderer = null;

pub fn main() u8 {
    return @intCast(SDL_EnterAppMainCallbacks(0, null, init, iterate, event, quit));
}

fn init(appstate: ?*?*anyopaque, argc: c_int, argv: [*c][*c]u8) callconv(.c) sdl.SDL_AppResult {
    _ = appstate;
    _ = argc;
    _ = argv;

    // Initialize SDL
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return fail();

    sdl.SDL_Log("video driver: %s", sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null"));

    // Create a window and renderer
    if (!sdl.SDL_CreateWindowAndRenderer(
        "example",
        960,
        540,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) return fail();

    return sdl.SDL_APP_CONTINUE;
}

fn event(appstate: ?*anyopaque, ev: [*c]sdl.SDL_Event) callconv(.c) sdl.SDL_AppResult {
    _ = appstate;
    if (ev.*.type == sdl.SDL_EVENT_QUIT) return sdl.SDL_APP_SUCCESS;
    return sdl.SDL_APP_CONTINUE;
}

fn iterate(appstate: ?*anyopaque) callconv(.c) sdl.SDL_AppResult {
    _ = appstate;

    // Update the background color
    const now = @as(f64, @floatFromInt(sdl.SDL_GetTicks())) / 1000.0;
    const r: f32 = @floatCast(0.5 + 0.5 * @sin(now));
    const g: f32 = @floatCast(0.5 + 0.5 * @sin(now + std.math.pi * 2 / 3.0));
    const b: f32 = @floatCast(0.5 + 0.5 * @sin(now + std.math.pi * 4 / 3.0));

    if (!sdl.SDL_SetRenderDrawColorFloat(renderer, r, g, b, sdl.SDL_ALPHA_OPAQUE_FLOAT)) return fail();
    if (!sdl.SDL_RenderClear(renderer)) return fail();
    if (!sdl.SDL_RenderPresent(renderer)) return fail();

    return sdl.SDL_APP_CONTINUE;
}

fn fail() sdl.SDL_AppResult {
    sdl.SDL_Log("%s", sdl.SDL_GetError());
    return sdl.SDL_APP_FAILURE;
}

fn quit(appstate: ?*anyopaque, result: sdl.SDL_AppResult) callconv(.c) void {
    _ = appstate;
    _ = result;
    sdl.SDL_DestroyRenderer(renderer);
    sdl.SDL_DestroyWindow(window);
    // SDL calls `SDL_Quit` for us after this callback returns
}
