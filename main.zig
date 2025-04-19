const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const Player = struct {
    x: f32,
    y: f32,
    size: f32,
    speed: f32,
    color: c.Color,
};

// Game constants
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;
const GRID_SIZE = 20;

pub fn main() !void {
    // Initialize window
    c.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Game Engine - Zig + Raylib");
    defer c.CloseWindow();
    
    // Set target FPS
    c.SetTargetFPS(60);
    
    // Initialize player
    var player = Player{
        .x = SCREEN_WIDTH / 2,
        .y = SCREEN_HEIGHT / 2,
        .size = 20,
        .speed = 4.0,
        .color = c.BLUE,
    };
    
    // Game loop
    while (!c.WindowShouldClose()) {
        // Update
        updatePlayer(&player);
        
        // Draw
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);
        renderGrid();
        renderPlayer(player);
        renderUI();
        c.EndDrawing();
    }
}

fn updatePlayer(player: *Player) void {
    // Handle input for player movement
    if (c.IsKeyDown(c.KEY_W) or c.IsKeyDown(c.KEY_UP)) {
        player.y -= player.speed;
    }
    if (c.IsKeyDown(c.KEY_S) or c.IsKeyDown(c.KEY_DOWN)) {
        player.y += player.speed;
    }
    if (c.IsKeyDown(c.KEY_A) or c.IsKeyDown(c.KEY_LEFT)) {
        player.x -= player.speed;
    }
    if (c.IsKeyDown(c.KEY_D) or c.IsKeyDown(c.KEY_RIGHT)) {
        player.x += player.speed;
    }
    
    // Keep player within screen bounds
    if (player.x < 0) player.x = 0;
    if (player.x > SCREEN_WIDTH - player.size) player.x = SCREEN_WIDTH - player.size;
    if (player.y < 0) player.y = 0;
    if (player.y > SCREEN_HEIGHT - player.size) player.y = SCREEN_HEIGHT - player.size;
}

fn renderGrid() void {
    // Draw grid for better visual reference
    const lightGray = c.Color{ .r = 230, .g = 230, .b = 230, .a = 255 };
    
    // Draw vertical lines
    var x: i32 = 0;
    while (x < SCREEN_WIDTH) : (x += GRID_SIZE) {
        c.DrawLine(x, 0, x, SCREEN_HEIGHT, lightGray);
    }
    
    // Draw horizontal lines
    var y: i32 = 0;
    while (y < SCREEN_HEIGHT) : (y += GRID_SIZE) {
        c.DrawLine(0, y, SCREEN_WIDTH, y, lightGray);
    }
}

fn renderPlayer(player: Player) void {
    // Draw player
    c.DrawRectangle(
        @intFromFloat(player.x), 
        @intFromFloat(player.y), 
        @intFromFloat(player.size), 
        @intFromFloat(player.size), 
        player.color
    );
    
    // Draw player outline
    c.DrawRectangleLines(
        @intFromFloat(player.x), 
        @intFromFloat(player.y), 
        @intFromFloat(player.size), 
        @intFromFloat(player.size), 
        c.BLACK
    );
}

fn renderUI() void {
    // Draw game info
    c.DrawText("Game Engine Demo - Move with Arrow Keys or WASD", 20, 20, 20, c.DARKGRAY);
    c.DrawFPS(SCREEN_WIDTH - 100, 10);
}