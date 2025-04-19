const std = @import("std");
const entity = @import("entity.zig");
const map = @import("map.zig");
const inventory = @import("inventory.zig");
const quest = @import("quest.zig");

pub const GameState = struct {
    player_position: struct {
        x: f32,
        y: f32,
    },
    player_health: i32,
    current_map_id: []const u8,
    inventory_slots: []inventory.InventorySlot,
    inventory_gold: u32,
    quest_states: []struct {
        id: []const u8,
        status: quest.QuestStatus,
        objectives: []struct {
            id: []const u8,
            current_count: u32,
            completed: bool,
        },
    },
    game_flags: std.StringHashMap(bool),
    
    pub fn init(allocator: std.mem.Allocator) !GameState {
        return .{
            .player_position = .{
                .x = 0,
                .y = 0,
            },
            .player_health = 100,
            .current_map_id = "default_map",
            .inventory_slots = &.{},
            .inventory_gold = 0,
            .quest_states = &.{},
            .game_flags = std.StringHashMap(bool).init(allocator),
        };
    }
    
    pub fn deinit(self: *GameState) void {
        self.game_flags.deinit();
    }
};

pub const SaveSystem = struct {
    allocator: std.mem.Allocator,
    save_directory: []const u8,
    current_slot: usize,
    game_flags: std.StringHashMap(bool),
    
    pub fn init(allocator: std.mem.Allocator, save_directory: []const u8) SaveSystem {
        return .{
            .allocator = allocator,
            .save_directory = save_directory,
            .current_slot = 0,
            .game_flags = std.StringHashMap(bool).init(allocator),
        };
    }
    
    pub fn deinit(self: *SaveSystem) void {
        self.game_flags.deinit();
    }
    
    pub fn saveGame(
        self: *SaveSystem,
        player_entity: ?*entity.Entity,
        current_map: *map.Map,
        player_inventory: *inventory.Inventory,
        quest_system: *quest.QuestSystem
    ) !void {
        _ = current_map;
        
        // Create a new game state to save
        var game_state = try GameState.init(self.allocator);
        defer game_state.deinit();
        
        // Save player position and stats
        if (player_entity) |player| {
            const transform_ptr = player.getComponent(entity.ComponentType.Transform) orelse {
                return error.MissingPlayerTransform;
            };
            const transform = @as(*entity.Transform, @ptrCast(@alignCast(transform_ptr))).*;
            
            game_state.player_position.x = transform.x;
            game_state.player_position.y = transform.y;
            
            // TODO: Save other player stats
        }
        
        // Save inventory
        // For simplicity, we'll just count how many of each item the player has
        var inventory_items = std.StringHashMap(u32).init(self.allocator);
        defer inventory_items.deinit();
        
        for (player_inventory.slots) |slot| {
            if (slot.item_id) |id| {
                const entry = try inventory_items.getOrPut(id);
                if (entry.found_existing) {
                    entry.value_ptr.* += slot.count;
                } else {
                    entry.value_ptr.* = slot.count;
                }
            }
        }
        
        game_state.inventory_gold = player_inventory.gold;
        
        // Save quests
        var active_quests = try quest_system.getActiveQuests(self.allocator);
        defer active_quests.deinit();
        
        // Save game flags
        game_state.game_flags = self.game_flags;
        
        // Build the save file path
        const save_filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/save_{d}.json",
            .{ self.save_directory, self.current_slot }
        );
        defer self.allocator.free(save_filename);
        
        // TODO: Serialize game_state to JSON and write to file
        // This would typically use a JSON library
        
        // For now, just print a message
        std.debug.print("Game saved to slot {d}\n", .{self.current_slot});
    }
    
    pub fn loadGame(
        self: *SaveSystem,
        entity_manager: *entity.EntityManager,
        map_manager: *map.Map,
        player_inventory: *inventory.Inventory,
        quest_system: *quest.QuestSystem
    ) !void {
        _ = entity_manager;
        _ = map_manager;
        _ = player_inventory;
        _ = quest_system;
        
        // Build the save file path
        const save_filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/save_{d}.json",
            .{ self.save_directory, self.current_slot }
        );
        defer self.allocator.free(save_filename);
        
        // TODO: Load and parse JSON file into GameState
        
        // For now, just print a message
        std.debug.print("Game loaded from slot {d}\n", .{self.current_slot});
    }
    
    pub fn setFlag(self: *SaveSystem, flag_name: []const u8, value: bool) !void {
        try self.game_flags.put(flag_name, value);
    }
    
    pub fn getFlag(self: *SaveSystem, flag_name: []const u8) bool {
        return self.game_flags.get(flag_name) orelse false;
    }
    
    pub fn setCurrentSlot(self: *SaveSystem, slot: usize) void {
        self.current_slot = slot;
    }
    
    pub fn doesSaveExist(self: *SaveSystem, slot: usize) bool {
        const save_filename = std.fmt.allocPrint(
            self.allocator,
            "{s}/save_{d}.json",
            .{ self.save_directory, slot }
        ) catch return false;
        defer self.allocator.free(save_filename);
        
        var file = std.fs.openFileAbsolute(save_filename, .{}) catch return false;
        file.close();
        
        return true;
    }
    
    pub fn listSaveSlots(self: *SaveSystem) !std.ArrayList(usize) {
        var result = std.ArrayList(usize).init(self.allocator);
        
        // Check the first 10 save slots
        for (0..10) |slot| {
            if (self.doesSaveExist(slot)) {
                try result.append(slot);
            }
        }
        
        return result;
    }
};