const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

// Entity structs
const Entity = struct {
    x: f32,
    y: f32,
    size: f32,
    color: c.Color,
    active: bool,
};

const Player = struct {
    entity: Entity,
    speed: f32,
    health: i32,
};

const Enemy = struct {
    entity: Entity,
    speed: f32,
    direction: f32,
    damage: i32,
};

const Collectible = struct {
    entity: Entity,
    value: i32,
};

const Obstacle = struct {
    entity: Entity,
};

// Game constants
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;
const GRID_SIZE = 20;
const MAX_ENEMIES = 8;
const MAX_OBSTACLES = 12;
const MAX_COLLECTIBLES = 6;

// Game state
var score: i32 = 0;
var game_over: bool = false;

fn createRandomCollectible() Collectible {
    return Collectible{
        .entity = Entity{
            .x = @as(f32, @floatFromInt(c.GetRandomValue(0, SCREEN_WIDTH - 15))),
            .y = @as(f32, @floatFromInt(c.GetRandomValue(0, SCREEN_HEIGHT - 15))),
            .size = 15,
            .color = c.GREEN,
            .active = true,
        },
        .value = 5,
    };
}

fn initGame(
    player: *Player, 
    enemies: *[MAX_ENEMIES]Enemy, 
    obstacles: *[MAX_OBSTACLES]Obstacle,
    collectibles: *[MAX_COLLECTIBLES]Collectible
) void {
    // Reset game state
    game_over = false;
    score = 0;
    
    // Initialize player
    player.* = Player{
        .entity = Entity{
            .x = SCREEN_WIDTH / 2,
            .y = SCREEN_HEIGHT / 2,
            .size = 20,
            .color = c.BLUE,
            .active = true,
        },
        .speed = 4.0,
        .health = 3,
    };
    
    // Initialize enemies
    for (0..MAX_ENEMIES) |i| {
        enemies[i] = createRandomEnemy();
    }
    
    // Initialize obstacles
    for (0..MAX_OBSTACLES) |i| {
        obstacles[i] = createRandomObstacle();
    }
    
    // Initialize collectibles
    for (0..MAX_COLLECTIBLES) |i| {
        collectibles[i] = createRandomCollectible();
    }
}

pub fn main() !void {
    // Initialize window
    c.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Game Engine - Zig + Raylib");
    defer c.CloseWindow();
    
    // Initialize random
    c.SetRandomSeed(@as(u32, @truncate(@as(u64, @bitCast(std.time.milliTimestamp())))));
    
    // Set target FPS
    c.SetTargetFPS(60);
    
    // Game entities
    var player: Player = undefined;
    var enemies: [MAX_ENEMIES]Enemy = undefined;
    var obstacles: [MAX_OBSTACLES]Obstacle = undefined;
    var collectibles: [MAX_COLLECTIBLES]Collectible = undefined;
    
    // Initialize game
    initGame(&player, &enemies, &obstacles, &collectibles);
    
    // Game loop
    while (!c.WindowShouldClose()) {
        // Check for restart
        if (game_over and c.IsKeyPressed(c.KEY_R)) {
            initGame(&player, &enemies, &obstacles, &collectibles);
        }
        
        // Update
        if (!game_over) {
            updatePlayer(&player);
            updateEnemies(&enemies);
            
            // Check collisions
            checkCollisions(&player, &enemies, &obstacles, &collectibles);
            
            // Check if we need to respawn collectibles
            var active_collectibles: usize = 0;
            for (collectibles) |collectible| {
                if (collectible.entity.active) {
                    active_collectibles += 1;
                }
            }
            
            if (active_collectibles < 2) {
                // Respawn a collectible
                for (0..MAX_COLLECTIBLES) |i| {
                    if (!collectibles[i].entity.active) {
                        collectibles[i] = createRandomCollectible();
                        break;
                    }
                }
            }
        }
        
        // Draw
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);
        
        renderGrid();
        renderObstacles(obstacles);
        renderCollectibles(collectibles);
        renderEnemies(enemies);
        renderPlayer(player);
        renderUI(player);
        
        if (game_over) {
            renderGameOver();
        }
        
        c.EndDrawing();
    }
}

fn createRandomEnemy() Enemy {
    return Enemy{
        .entity = Entity{
            .x = @as(f32, @floatFromInt(c.GetRandomValue(0, SCREEN_WIDTH - 20))),
            .y = @as(f32, @floatFromInt(c.GetRandomValue(0, SCREEN_HEIGHT - 20))),
            .size = 15,
            .color = c.RED,
            .active = true,
        },
        .speed = @as(f32, @floatFromInt(c.GetRandomValue(1, 3))),
        .direction = @as(f32, @floatFromInt(c.GetRandomValue(0, 359))),
        .damage = 1,
    };
}

fn createRandomObstacle() Obstacle {
    return Obstacle{
        .entity = Entity{
            .x = @as(f32, @floatFromInt(c.GetRandomValue(0, SCREEN_WIDTH - 30))),
            .y = @as(f32, @floatFromInt(c.GetRandomValue(0, SCREEN_HEIGHT - 30))),
            .size = 30,
            .color = c.DARKGRAY,
            .active = true,
        },
    };
}

fn updatePlayer(player: *Player) void {
    if (!player.entity.active) return;
    
    // Handle input for player movement
    if (c.IsKeyDown(c.KEY_W) or c.IsKeyDown(c.KEY_UP)) {
        player.entity.y -= player.speed;
    }
    if (c.IsKeyDown(c.KEY_S) or c.IsKeyDown(c.KEY_DOWN)) {
        player.entity.y += player.speed;
    }
    if (c.IsKeyDown(c.KEY_A) or c.IsKeyDown(c.KEY_LEFT)) {
        player.entity.x -= player.speed;
    }
    if (c.IsKeyDown(c.KEY_D) or c.IsKeyDown(c.KEY_RIGHT)) {
        player.entity.x += player.speed;
    }
    
    // Keep player within screen bounds
    if (player.entity.x < 0) player.entity.x = 0;
    if (player.entity.x > SCREEN_WIDTH - player.entity.size) player.entity.x = SCREEN_WIDTH - player.entity.size;
    if (player.entity.y < 0) player.entity.y = 0;
    if (player.entity.y > SCREEN_HEIGHT - player.entity.size) player.entity.y = SCREEN_HEIGHT - player.entity.size;
}

fn updateEnemies(enemies: *[MAX_ENEMIES]Enemy) void {
    for (0..MAX_ENEMIES) |i| {
        var enemy = &enemies[i];
        if (!enemy.entity.active) continue;
        
        // Update position based on direction
        const rad = enemy.direction * std.math.pi / 180.0;
        enemy.entity.x += @cos(rad) * enemy.speed;
        enemy.entity.y += @sin(rad) * enemy.speed;
        
        // Bounce off screen edges
        if (enemy.entity.x <= 0 or enemy.entity.x >= SCREEN_WIDTH - enemy.entity.size) {
            enemy.direction = 180.0 - enemy.direction;
        }
        
        if (enemy.entity.y <= 0 or enemy.entity.y >= SCREEN_HEIGHT - enemy.entity.size) {
            enemy.direction = 360.0 - enemy.direction;
        }
        
        // Normalize direction
        while (enemy.direction >= 360.0) enemy.direction -= 360.0;
        while (enemy.direction < 0.0) enemy.direction += 360.0;
    }
}

fn checkCollision(a: Entity, b: Entity) bool {
    const rect1 = c.Rectangle{
        .x = a.x,
        .y = a.y,
        .width = a.size,
        .height = a.size,
    };
    
    const rect2 = c.Rectangle{
        .x = b.x,
        .y = b.y,
        .width = b.size,
        .height = b.size,
    };
    
    return c.CheckCollisionRecs(rect1, rect2);
}

fn checkCollisions(
    player: *Player, 
    enemies: *[MAX_ENEMIES]Enemy, 
    obstacles: *[MAX_OBSTACLES]Obstacle,
    collectibles: *[MAX_COLLECTIBLES]Collectible
) void {
    if (!player.entity.active) return;
    
    // Check collisions with enemies
    for (0..MAX_ENEMIES) |i| {
        const enemy = &enemies[i];
        if (!enemy.entity.active) continue;
        
        if (checkCollision(player.entity, enemy.entity)) {
            player.health -= enemy.damage;
            enemy.entity.active = false; // Remove enemy when hit
            
            // Create a new enemy
            enemies[i] = createRandomEnemy();
            
            // Check if player is dead
            if (player.health <= 0) {
                player.entity.active = false;
                game_over = true;
            }
        }
    }
    
    // Check collisions with collectibles
    for (0..MAX_COLLECTIBLES) |i| {
        const collectible = &collectibles[i];
        if (!collectible.entity.active) continue;
        
        if (checkCollision(player.entity, collectible.entity)) {
            // Collect the item
            score += collectible.value;
            collectible.entity.active = false;
        }
    }
    
    // Check collisions with obstacles
    for (0..MAX_OBSTACLES) |i| {
        const obstacle = obstacles[i];
        if (!obstacle.entity.active) continue;
        
        if (checkCollision(player.entity, obstacle.entity)) {
            // Push player back
            const dx = player.entity.x - obstacle.entity.x;
            const dy = player.entity.y - obstacle.entity.y;
            
            // Normalize push direction
            const length = @sqrt(dx * dx + dy * dy);
            if (length > 0) {
                const push_x = dx / length * player.speed;
                const push_y = dy / length * player.speed;
                
                player.entity.x += push_x;
                player.entity.y += push_y;
            }
        }
    }
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
    if (!player.entity.active) return;
    
    // Draw player
    c.DrawRectangle(
        @intFromFloat(player.entity.x), 
        @intFromFloat(player.entity.y), 
        @intFromFloat(player.entity.size), 
        @intFromFloat(player.entity.size), 
        player.entity.color
    );
    
    // Draw player outline
    c.DrawRectangleLines(
        @intFromFloat(player.entity.x), 
        @intFromFloat(player.entity.y), 
        @intFromFloat(player.entity.size), 
        @intFromFloat(player.entity.size), 
        c.BLACK
    );
}

fn renderEnemies(enemies: [MAX_ENEMIES]Enemy) void {
    for (enemies) |enemy| {
        if (!enemy.entity.active) continue;
        
        // Draw enemy
        c.DrawRectangle(
            @intFromFloat(enemy.entity.x), 
            @intFromFloat(enemy.entity.y), 
            @intFromFloat(enemy.entity.size), 
            @intFromFloat(enemy.entity.size), 
            enemy.entity.color
        );
    }
}

fn renderObstacles(obstacles: [MAX_OBSTACLES]Obstacle) void {
    for (obstacles) |obstacle| {
        if (!obstacle.entity.active) continue;
        
        // Draw obstacle
        c.DrawRectangle(
            @intFromFloat(obstacle.entity.x), 
            @intFromFloat(obstacle.entity.y), 
            @intFromFloat(obstacle.entity.size), 
            @intFromFloat(obstacle.entity.size), 
            obstacle.entity.color
        );
    }
}

fn renderCollectibles(collectibles: [MAX_COLLECTIBLES]Collectible) void {
    for (collectibles) |collectible| {
        if (!collectible.entity.active) continue;
        
        // Draw collectible
        c.DrawCircle(
            @intFromFloat(collectible.entity.x + collectible.entity.size/2), 
            @intFromFloat(collectible.entity.y + collectible.entity.size/2), 
            collectible.entity.size/2, 
            collectible.entity.color
        );
    }
}

fn renderUI(player: Player) void {
    // Draw game info
    c.DrawText("Game Engine Demo - Move with Arrow Keys or WASD", 20, 20, 20, c.DARKGRAY);
    c.DrawText(c.TextFormat("Score: %d", score), 20, 50, 20, c.DARKGRAY);
    c.DrawText(c.TextFormat("Health: %d", player.health), 20, 80, 20, c.DARKGRAY);
    c.DrawFPS(SCREEN_WIDTH - 100, 10);
}

fn renderGameOver() void {
    const text = "GAME OVER";
    const font_size = 40;
    const text_width = c.MeasureText(text, font_size);
    
    c.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, c.ColorAlpha(c.BLACK, 0.7));
    c.DrawText(
        text, 
        @divTrunc(SCREEN_WIDTH - text_width, 2), 
        @divTrunc(SCREEN_HEIGHT, 2) - 40, 
        font_size, 
        c.RED
    );
    
    const score_text = c.TextFormat("Final Score: %d", score);
    const score_width = c.MeasureText(score_text, 30);
    c.DrawText(
        score_text, 
        @divTrunc(SCREEN_WIDTH - score_width, 2), 
        @divTrunc(SCREEN_HEIGHT, 2) + 20, 
        30, 
        c.WHITE
    );
    
    const restart_text = "Press R to restart";
    const restart_width = c.MeasureText(restart_text, 20);
    c.DrawText(
        restart_text, 
        @divTrunc(SCREEN_WIDTH - restart_width, 2), 
        @divTrunc(SCREEN_HEIGHT, 2) + 70, 
        20, 
        c.WHITE
    );
    
    // TODO: Implement restart functionality
}