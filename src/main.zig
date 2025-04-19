const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const entity_mod = @import("engine/entity.zig");
const map_mod = @import("engine/map.zig");
const dialogue_mod = @import("engine/dialogue.zig");
const quest_mod = @import("engine/quest.zig");
const npc_mod = @import("engine/npc.zig");
const inventory_mod = @import("engine/inventory.zig");
const save_mod = @import("engine/save.zig");

// Game state enum
const GameState = enum {
    MainMenu,
    Playing,
    Paused,
    Dialogue,
    Inventory,
    QuestLog,
    GameOver,
};

// Game configuration
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
const TILE_SIZE = 32;
const PLAYER_SPEED = 3.0;

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize Raylib
    c.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Zig RPG Game Engine");
    defer c.CloseWindow();
    c.SetTargetFPS(60);
    
    // Initialize systems
    var entity_manager = entity_mod.EntityManager.init(allocator);
    defer entity_manager.deinit();
    
    // Load map
    var game_map = try map_mod.Map.loadFromFile(allocator, "");
    defer game_map.deinit();
    
    // Initialize dialogue system
    var dialogue_system = dialogue_mod.DialogueSystem.init(allocator);
    defer dialogue_system.deinit();
    try dialogue_system.loadDialogue("test_npc", "");
    
    // Initialize quest system
    var quest_system = quest_mod.QuestSystem.init(allocator);
    defer quest_system.deinit();
    try quest_system.loadQuest("lost_item", "");
    
    // Initialize item registry
    var item_registry = try inventory_mod.ItemRegistry.init(allocator, 100);
    defer item_registry.deinit();
    try item_registry.loadDefaultItems();
    
    // Initialize player inventory
    var player_inventory = try inventory_mod.Inventory.init(allocator, 20, &item_registry);
    defer player_inventory.deinit();
    _ = player_inventory.addItem("potion_health", 2);
    _ = player_inventory.addItem("gold_coin", 50);
    
    // Initialize NPC manager
    var npc_manager = npc_mod.NPCManager.init(allocator, &entity_manager, &dialogue_system, &quest_system);
    
    // Initialize save system
    var save_system = save_mod.SaveSystem.init(allocator, "saves");
    defer save_system.deinit();
    
    // Create player entity
    const player_entity = try entity_manager.createEntity(entity_mod.EntityType.Player, "Player");
    var player_transform = entity_mod.Transform.init(
        SCREEN_WIDTH / 2, 
        SCREEN_HEIGHT / 2, 
        TILE_SIZE, 
        TILE_SIZE
    );
    try player_entity.addComponent(entity_mod.Transform, entity_mod.ComponentType.Transform, &player_transform);
    
    var player_sprite = entity_mod.Sprite.init(c.Texture2D{}, c.BLUE);
    try player_entity.addComponent(entity_mod.Sprite, entity_mod.ComponentType.Sprite, &player_sprite);
    
    var player_collider = entity_mod.Collider.init(true);
    try player_entity.addComponent(entity_mod.Collider, entity_mod.ComponentType.Collider, &player_collider);
    
    npc_manager.setPlayerEntity(player_entity.id);
    
    // Create test NPC
    const npc_id = try npc_manager.createNPC("Villager", 300, 200, npc_mod.NPCType.QuestGiver);
    try npc_manager.addDialogueToNPC(npc_id, "test_npc");
    try npc_manager.addQuestToNPC(npc_id, "lost_item");
    
    // Add some test items to the world
    const amulet_entity = try entity_manager.createEntity(entity_mod.EntityType.Item, "Lost Amulet");
    var amulet_transform = entity_mod.Transform.init(500, 300, 16, 16);
    try amulet_entity.addComponent(entity_mod.Transform, entity_mod.ComponentType.Transform, &amulet_transform);
    
    var amulet_sprite = entity_mod.Sprite.init(c.Texture2D{}, c.PURPLE);
    try amulet_entity.addComponent(entity_mod.Sprite, entity_mod.ComponentType.Sprite, &amulet_sprite);
    
    // Game variables
    var camera_x: f32 = 0;
    var camera_y: f32 = 0;
    var game_state = GameState.Playing;
    
    // Main game loop
    while (!c.WindowShouldClose()) {
        // Process inputs
        const player_transform_ptr = player_entity.getComponent(entity_mod.ComponentType.Transform) orelse continue;
        var player_transform_ref = @as(*entity_mod.Transform, @ptrCast(@alignCast(player_transform_ptr)));
        
        // Handle game state transitions
        if (c.IsKeyPressed(c.KEY_ESCAPE)) {
            if (game_state == .Playing) {
                game_state = .Paused;
            } else if (game_state == .Paused) {
                game_state = .Playing;
            }
        }
        
        if (c.IsKeyPressed(c.KEY_I)) {
            if (game_state == .Playing) {
                game_state = .Inventory;
                player_inventory.show_ui = true;
            } else if (game_state == .Inventory) {
                game_state = .Playing;
                player_inventory.show_ui = false;
            }
        }
        
        if (c.IsKeyPressed(c.KEY_Q)) {
            if (game_state == .Playing) {
                game_state = .QuestLog;
            } else if (game_state == .QuestLog) {
                game_state = .Playing;
            }
        }
        
        // Update based on game state
        switch (game_state) {
            .Playing => {
                // Player movement
                var move_x: f32 = 0;
                var move_y: f32 = 0;
                
                if (c.IsKeyDown(c.KEY_W) or c.IsKeyDown(c.KEY_UP)) move_y -= 1;
                if (c.IsKeyDown(c.KEY_S) or c.IsKeyDown(c.KEY_DOWN)) move_y += 1;
                if (c.IsKeyDown(c.KEY_A) or c.IsKeyDown(c.KEY_LEFT)) move_x -= 1;
                if (c.IsKeyDown(c.KEY_D) or c.IsKeyDown(c.KEY_RIGHT)) move_x += 1;
                
                // Normalize diagonal movement
                if (move_x != 0 and move_y != 0) {
                    const length = @sqrt(move_x * move_x + move_y * move_y);
                    move_x /= length;
                    move_y /= length;
                }
                
                // Apply movement
                player_transform_ref.x += move_x * PLAYER_SPEED;
                player_transform_ref.y += move_y * PLAYER_SPEED;
                
                // Check boundaries
                player_transform_ref.x = @max(0, @min(player_transform_ref.x, @as(f32, @floatFromInt(game_map.width * game_map.tile_size)) - player_transform_ref.width));
                player_transform_ref.y = @max(0, @min(player_transform_ref.y, @as(f32, @floatFromInt(game_map.height * game_map.tile_size)) - player_transform_ref.height));
                
                // Update camera to follow player
                camera_x = player_transform_ref.x - SCREEN_WIDTH / 2 + player_transform_ref.width / 2;
                camera_y = player_transform_ref.y - SCREEN_HEIGHT / 2 + player_transform_ref.height / 2;
                
                // Clamp camera to map boundaries
                camera_x = @max(0, @min(camera_x, @as(f32, @floatFromInt(game_map.width * game_map.tile_size)) - SCREEN_WIDTH));
                camera_y = @max(0, @min(camera_y, @as(f32, @floatFromInt(game_map.height * game_map.tile_size)) - SCREEN_HEIGHT));
                
                // Update NPC manager
                npc_manager.update();
                
                // Check for interactions with game items
                for (entity_manager.entities.items) |*e| {
                    if (e.type_id == entity_mod.EntityType.Item and e.is_active) {
                        const item_transform_ptr = e.getComponent(entity_mod.ComponentType.Transform) orelse continue;
                        const item_transform = @as(*entity_mod.Transform, @ptrCast(@alignCast(item_transform_ptr))).*;
                        
                        // Check if player is close to item
                        const dx = player_transform_ref.x - item_transform.x;
                        const dy = player_transform_ref.y - item_transform.y;
                        const distance = @sqrt(dx * dx + dy * dy);
                        
                        if (distance < 30 and c.IsKeyPressed(c.KEY_E)) {
                            if (std.mem.eql(u8, e.name, "Lost Amulet")) {
                                // Add amulet to inventory
                                _ = player_inventory.addItem("item_amulet", 1);
                                
                                // Update quest
                                _ = quest_system.updateObjective("lost_item", "find_amulet", 1);
                                
                                // Deactivate item entity
                                e.is_active = false;
                            }
                        }
                    }
                }
                
                // Check for NPCs to talk to
                // NPC manager handles this in its update method
                
                // Check if dialogue was activated
                if (dialogue_system.active_dialogue != null) {
                    game_state = .Dialogue;
                }
            },
            .Dialogue => {
                // Handle dialogue navigation
                if (c.IsKeyPressed(c.KEY_DOWN)) {
                    dialogue_system.selectNextOption();
                }
                if (c.IsKeyPressed(c.KEY_UP)) {
                    dialogue_system.selectPrevOption();
                }
                if (c.IsKeyPressed(c.KEY_ENTER) or c.IsKeyPressed(c.KEY_E)) {
                    if (dialogue_system.executeSelectedOption()) |option| {
                        // Handle any actions from the dialogue option
                        if (option.action == .StartQuest) {
                            if (option.action_data == .start_quest) {
                                const quest_id = option.action_data.start_quest;
                                _ = quest_system.startQuest(quest_id);
                                quest_system.setActiveQuest(quest_id);
                            }
                        }
                    }
                }
                
                // Check if dialogue ended
                if (dialogue_system.active_dialogue == null) {
                    game_state = .Playing;
                }
            },
            .Inventory => {
                // Handle inventory navigation
                if (c.IsKeyPressed(c.KEY_DOWN)) {
                    player_inventory.selected_slot += 5; // Move down one row
                    if (player_inventory.selected_slot >= player_inventory.capacity) {
                        player_inventory.selected_slot %= player_inventory.capacity;
                    }
                }
                if (c.IsKeyPressed(c.KEY_UP)) {
                    if (player_inventory.selected_slot < 5) {
                        player_inventory.selected_slot = player_inventory.capacity - (5 - player_inventory.selected_slot);
                    } else {
                        player_inventory.selected_slot -= 5;
                    }
                }
                if (c.IsKeyPressed(c.KEY_RIGHT)) {
                    player_inventory.selected_slot += 1;
                    if (player_inventory.selected_slot >= player_inventory.capacity) {
                        player_inventory.selected_slot = 0;
                    }
                }
                if (c.IsKeyPressed(c.KEY_LEFT)) {
                    if (player_inventory.selected_slot == 0) {
                        player_inventory.selected_slot = player_inventory.capacity - 1;
                    } else {
                        player_inventory.selected_slot -= 1;
                    }
                }
                if (c.IsKeyPressed(c.KEY_ENTER)) {
                    // Use the selected item
                    _ = player_inventory.useItem(player_inventory.selected_slot);
                }
            },
            .QuestLog => {
                // View quest log - no special handling needed
            },
            .Paused => {
                // Handle pause menu
                if (c.IsKeyPressed(c.KEY_S)) {
                    // Save game
                    save_system.saveGame(player_entity, &game_map, &player_inventory, &quest_system) catch {};
                }
                if (c.IsKeyPressed(c.KEY_L)) {
                    // Load game
                    save_system.loadGame(&entity_manager, &game_map, &player_inventory, &quest_system) catch {};
                }
            },
            .MainMenu, .GameOver => {
                // Handle main menu or game over screen
            },
        }
        
        // Drawing
        c.BeginDrawing();
        c.ClearBackground(c.BLACK);
        
        // Render game world
        game_map.render(camera_x, camera_y);
        entity_manager.render();
        
        // Render UI based on game state
        switch (game_state) {
            .Dialogue => dialogue_system.render(),
            .Inventory => player_inventory.render(),
            .QuestLog => quest_system.renderQuestLog(),
            .Paused => {
                // Draw pause menu
                const text = "Game Paused";
                const font_size = 40;
                const text_width = c.MeasureText(text, font_size);
                
                c.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, c.ColorAlpha(c.BLACK, 0.7));
                c.DrawText(
                    text, 
                    @divTrunc(SCREEN_WIDTH - text_width, 2), 
                    @divTrunc(SCREEN_HEIGHT, 2) - 40, 
                    font_size, 
                    c.WHITE
                );
                
                c.DrawText(
                    "Press S to Save", 
                    @divTrunc(SCREEN_WIDTH, 2) - 80, 
                    @divTrunc(SCREEN_HEIGHT, 2) + 20, 
                    20, 
                    c.LIGHTGRAY
                );
                
                c.DrawText(
                    "Press L to Load", 
                    @divTrunc(SCREEN_WIDTH, 2) - 80, 
                    @divTrunc(SCREEN_HEIGHT, 2) + 50, 
                    20, 
                    c.LIGHTGRAY
                );
                
                c.DrawText(
                    "Press ESC to Resume", 
                    @divTrunc(SCREEN_WIDTH, 2) - 100, 
                    @divTrunc(SCREEN_HEIGHT, 2) + 80, 
                    20, 
                    c.LIGHTGRAY
                );
            },
            .MainMenu => {
                // Draw main menu
                const title = "Zig RPG Game";
                const font_size = 50;
                const text_width = c.MeasureText(title, font_size);
                
                c.DrawText(
                    title, 
                    @divTrunc(SCREEN_WIDTH - text_width, 2), 
                    100, 
                    font_size, 
                    c.WHITE
                );
                
                c.DrawText(
                    "Press ENTER to Start", 
                    @divTrunc(SCREEN_WIDTH, 2) - 120, 
                    @divTrunc(SCREEN_HEIGHT, 2) + 50, 
                    25, 
                    c.WHITE
                );
            },
            .GameOver => {
                // Draw game over screen
                const text = "Game Over";
                const font_size = 50;
                const text_width = c.MeasureText(text, font_size);
                
                c.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, c.ColorAlpha(c.BLACK, 0.8));
                c.DrawText(
                    text, 
                    @divTrunc(SCREEN_WIDTH - text_width, 2), 
                    @divTrunc(SCREEN_HEIGHT, 2) - 40, 
                    font_size, 
                    c.RED
                );
            },
            else => {
                // Always render inventory hotbar
                player_inventory.renderHotbar();
                
                // Draw interaction hint if near an NPC or item
                var show_interaction_hint = false;
                var interaction_text: []const u8 = "Press E to interact";
                
                // Check for items
                for (entity_manager.entities.items) |e| {
                    if (e.type_id == entity_mod.EntityType.Item and e.is_active) {
                        var entity_mut = @constCast(&e);
                        const item_transform_ptr = entity_mut.getComponent(entity_mod.ComponentType.Transform) orelse continue;
                        const item_transform = @as(*entity_mod.Transform, @ptrCast(@alignCast(item_transform_ptr))).*;
                        
                        const dx = player_transform_ref.x - item_transform.x;
                        const dy = player_transform_ref.y - item_transform.y;
                        const distance = @sqrt(dx * dx + dy * dy);
                        
                        if (distance < 30) {
                            show_interaction_hint = true;
                            interaction_text = "Press E to pick up";
                            break;
                        }
                    }
                }
                
                // Check for NPCs
                for (entity_manager.entities.items) |e| {
                    if (e.type_id == entity_mod.EntityType.NPC) {
                        var entity_mut = @constCast(&e);
                        const npc_transform_ptr = entity_mut.getComponent(entity_mod.ComponentType.Transform) orelse continue;
                        const npc_transform = @as(*entity_mod.Transform, @ptrCast(@alignCast(npc_transform_ptr))).*;
                        
                        const dx = player_transform_ref.x - npc_transform.x;
                        const dy = player_transform_ref.y - npc_transform.y;
                        const distance = @sqrt(dx * dx + dy * dy);
                        
                        if (distance < 40) {
                            show_interaction_hint = true;
                            interaction_text = "Press E to talk";
                            break;
                        }
                    }
                }
                
                if (show_interaction_hint) {
                    const text_width = c.MeasureText(@ptrCast(interaction_text), 20);
                    c.DrawRectangle(
                        @divTrunc(SCREEN_WIDTH - text_width, 2) - 10, 
                        SCREEN_HEIGHT - 50, 
                        text_width + 20, 
                        30, 
                        c.ColorAlpha(c.BLACK, 0.7)
                    );
                    c.DrawText(
                        @ptrCast(interaction_text), 
                        @divTrunc(SCREEN_WIDTH - text_width, 2), 
                        SCREEN_HEIGHT - 45, 
                        20, 
                        c.WHITE
                    );
                }
                
                // Draw controls hint
                c.DrawText(
                    "WASD/Arrows: Move   E: Interact   I: Inventory   Q: Quests   ESC: Pause", 
                    10, 
                    10, 
                    16, 
                    c.LIGHTGRAY
                );
            },
        }
        
        c.EndDrawing();
    }
}