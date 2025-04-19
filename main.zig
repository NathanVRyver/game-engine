const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    const max_frames = 5;

    var frame: usize = 0;

    while (frame < max_frames) : (frame += 1) {
        try stdout.print("Frame {d}\n", .{frame});
        try update();
        try render();
        std.time.sleep(500 * std.time.ns_per_ms); // simulate 500ms/frame
    }

    try stdout.print("Exiting game loop.\n", .{});
}

fn update() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(" - Updating game state...\n", .{});
}

fn render() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(" - Rendering frame...\n", .{});
}
