const std = @import("std");

const c = @cImport(@cInclude("SDL2/SDL.h"));

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.debug.print("SDL Error {s}\n", .{c.SDL_GetError()});
        return error.FailedToInitSDL;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Test SDL+Zig", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, 800, 600, 0).?;
    defer c.SDL_DestroyWindow(window);

    var run: bool = true;
    while (run) {
        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT) {
                run = false;
            }
        }

        //Sleep for 10ms, to prevent the CPU from being eaten by 100000 loops per second
        std.time.sleep(std.time.ns_per_ms * 10);
    }
}
