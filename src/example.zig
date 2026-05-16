const std = @import("std");
const c = @import("sdl3_h");

const Io = std.Io;

pub fn main() void {
    var threaded_io: Io.Threaded = .init_single_threaded;
    const io = threaded_io.io();

    // Initialize SDL
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.panic("{s}", .{c.SDL_GetError()});
    }
    defer c.SDL_Quit();

    std.debug.print("video driver: {s}\n", .{c.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")});

    // Create a window and renderer
    var window: ?*c.SDL_Window = null;
    var renderer: ?*c.SDL_Renderer = null;
    if (!c.SDL_CreateWindowAndRenderer(
        "example",
        960,
        540,
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) {
        std.debug.panic("{s}", .{c.SDL_GetError()});
    }
    defer c.SDL_DestroyWindow(window);
    defer c.SDL_DestroyRenderer(renderer);

    // Main loop
    while (true) {
        // Poll events
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) {
                std.process.cleanExit(io);
                return;
            }
        }

        // Update the background color
        const now = @as(f64, @floatFromInt(c.SDL_GetTicks())) / 1000.0;
        const r: f32 = @floatCast(0.5 + 0.5 * @sin(now));
        const g: f32 = @floatCast(0.5 + 0.5 * @sin(now + std.math.pi * 2 / 3.0));
        const b: f32 = @floatCast(0.5 + 0.5 * @sin(now + std.math.pi * 4 / 3.0));

        if (!c.SDL_SetRenderDrawColorFloat(renderer, r, g, b, c.SDL_ALPHA_OPAQUE_FLOAT)) {
            std.debug.panic("{s}", .{c.SDL_GetError()});
        }
        if (!c.SDL_RenderClear(renderer)) {
            std.debug.panic("{s}", .{c.SDL_GetError()});
        }
        if (!c.SDL_RenderPresent(renderer)) {
            std.debug.panic("{s}", .{c.SDL_GetError()});
        }
    }
}
