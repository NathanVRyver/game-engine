const std = @import("std");

const Player = struct {
    x: usize,
    y: usize,
};

var player = Player{
    .x = 0,
    .y = 2,
};

const SCREEN_WIDTH = 10;
const SCREEN_HEIGHT = 5;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const max_frames = 10;
    var frame: usize = 0;

    while (frame < max_frames) : (frame += 1) {
        try update();
        try render();
        std.time.sleep(300 * std.time.ns_per_ms);
    }

    try stdout.print("Exiting game loop.\n", .{});
}

fn update() !void {
    // move player right each frame
    player.x = (player.x + 1) % SCREEN_WIDTH;
}

fn render() !void {
    const stdout = std.io.getStdOut().writer();

    // Clear screen buffer
    var screen: [SCREEN_HEIGHT][SCREEN_WIDTH]u8 = undefined;

    // Fill with dots
    for (screen) |*row| {
        for (row) |*cell| {
            cell.* = '.';
        }
    }

    // Place player
    screen[player.y][player.x] = 'P';

    // Print screen
    for (screen) |row| {
        try stdout.print("{s}\n", .{row});
    }

    try stdout.print("---\n", .{});
}
