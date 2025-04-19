const std = @import("std");
const os = std.os;
const io = std.io;
const fs = std.fs;
const time = std.time;

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
var game_running = true;

// Input handling
const Direction = enum {
    Up,
    Down,
    Left,
    Right,
    None,
};

fn getInput() !Direction {
    var buffer: [1]u8 = undefined;
    const stdin = io.getStdIn();
    
    // Simple non-blocking input check
    // This is a simplified approach - doesn't use raw mode
    const bytes_read = stdin.read(&buffer) catch 0;
    if (bytes_read == 0) return Direction.None;
    
    return switch (buffer[0]) {
        'w' => Direction.Up,
        's' => Direction.Down,
        'a' => Direction.Left,
        'd' => Direction.Right,
        'q' => {
            game_running = false;
            return Direction.None;
        },
        else => Direction.None,
    };
}

pub fn main() !void {
    const stdout = io.getStdOut().writer();
    
    // Set up terminal for game
    try stdout.print("Game starting. Controls: WASD to move, Q to quit\n", .{});
    time.sleep(2 * time.ns_per_s);
    
    while (game_running) {
        // Handle input
        const input = try getInput();
        
        // Update game state
        update(input);
        
        // Render screen
        try render();
        
        // Frame timing
        time.sleep(100 * time.ns_per_ms);
    }
    
    try stdout.print("Exiting game loop.\n", .{});
}
fn update(input: Direction) void {
    // Handle player movement based on input
    switch (input) {
        .Up => {
            if (player.y > 0) player.y -= 1;
        },
        .Down => {
            if (player.y < SCREEN_HEIGHT - 1) player.y += 1;
        },
        .Left => {
            if (player.x > 0) player.x -= 1;
        },
        .Right => {
            if (player.x < SCREEN_WIDTH - 1) player.x += 1;
        },
        .None => {}, // No movement
    }
}
fn clearScreen() !void {
    const stdout = io.getStdOut().writer();
    // ANSI escape code to clear screen and move cursor to top-left
    try stdout.print("\x1B[2J\x1B[H", .{});
}

fn render() !void {
    try clearScreen();
    
    const stdout = io.getStdOut().writer();
    // Create screen buffer
    var screen: [SCREEN_HEIGHT][SCREEN_WIDTH]u8 = undefined;
    
    // Fill with dots (using indices for assignment)
    for (0..SCREEN_HEIGHT) |y| {
        for (0..SCREEN_WIDTH) |x| {
            screen[y][x] = '.';
        }
    }
    
    // Place player
    screen[player.y][player.x] = 'P';
    
    // Print screen
    for (screen) |row| {
        try stdout.print("{s}\n", .{row});
    }
    
    // Print game info
    try stdout.print("---\nPosition: ({}, {})\n", .{player.x, player.y});
    try stdout.print("Controls: WASD to move, Q to quit\n", .{});
}
