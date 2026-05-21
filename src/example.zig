const std = @import("std");
const sdl = @import("sdl3");

const Io = std.Io;

pub fn main() void {
    var threaded_io: Io.Threaded = .init_single_threaded;
    const io = threaded_io.io();

    // Initialize SDL
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.panic("{s}", .{sdl.SDL_GetError()});
    }
    defer sdl.SDL_Quit();

    std.debug.print("video driver: {s}\n", .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")});

    // Create a window and renderer
    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;
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
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    // Main loop
    while (true) {
        // Poll events
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            if (event.type == sdl.SDL_EVENT_QUIT) {
                std.process.cleanExit(io);
                return;
            }
        }

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
    }
}
