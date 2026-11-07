const std = @import("std");
const sdl = @import("sdl3");

// main is provided by SDL_main.h, which calls the SDL_App* callbacks below
pub extern fn main(argc: c_int, argv: [*c][*c]u8) c_int;

var window: ?*sdl.SDL_Window = null;
var renderer: ?*sdl.SDL_Renderer = null;

export fn SDL_AppInit(appstate: ?*?*anyopaque, argc: c_int, argv: [*c][*c]u8) sdl.SDL_AppResult {
    _ = appstate;
    _ = argc;
    _ = argv;

    // Initialize SDL
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }

    std.debug.print("video driver: {s}\n", .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")});

    // Create a window and renderer
    if (!sdl.SDL_CreateWindowAndRenderer(
        "example",
        960,
        540,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }

    return sdl.SDL_APP_CONTINUE;
}

export fn SDL_AppEvent(appstate: ?*anyopaque, event: ?*sdl.SDL_Event) sdl.SDL_AppResult {
    _ = appstate;

    if (event.?.type == sdl.SDL_EVENT_QUIT) {
        return sdl.SDL_APP_SUCCESS;
    }
    return sdl.SDL_APP_CONTINUE;
}

export fn SDL_AppIterate(appstate: ?*anyopaque) sdl.SDL_AppResult {
    _ = appstate;

    // Update the background color
    const now = @as(f64, @floatFromInt(sdl.SDL_GetTicks())) / 1000.0;
    const r: f32 = @floatCast(0.5 + 0.5 * @sin(now));
    const g: f32 = @floatCast(0.5 + 0.5 * @sin(now + std.math.pi * 2 / 3.0));
    const b: f32 = @floatCast(0.5 + 0.5 * @sin(now + std.math.pi * 4 / 3.0));

    if (!sdl.SDL_SetRenderDrawColorFloat(renderer, r, g, b, sdl.SDL_ALPHA_OPAQUE_FLOAT)) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }
    if (!sdl.SDL_RenderClear(renderer)) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }
    if (!sdl.SDL_RenderPresent(renderer)) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }

    return sdl.SDL_APP_CONTINUE;
}

export fn SDL_AppQuit(appstate: ?*anyopaque, result: sdl.SDL_AppResult) void {
    _ = appstate;
    _ = result;
}
