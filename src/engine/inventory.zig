const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const ItemType = enum {
    Consumable,
    Weapon,
    Armor,
    QuestItem,
    Key,
};

pub const ItemEffect = enum {
    None,
    Heal,
    RestoreMana,
    DamageBoost,
    DefenseBoost,
    Unlock,
    TriggerQuest,
};

pub const Item = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    type_id: ItemType,
    texture_id: usize,
    value: u32,
    effect: ItemEffect = .None,
    effect_value: i32 = 0,
    quest_id: ?[]const u8 = null,
    stackable: bool = false,
    max_stack: u32 = 1,
    
    pub fn init(
        id: []const u8,
        name: []const u8,
        description: []const u8,
        type_id: ItemType,
        texture_id: usize,
        value: u32
    ) Item {
        return .{
            .id = id,
            .name = name,
            .description = description,
            .type_id = type_id,
            .texture_id = texture_id,
            .value = value,
        };
    }
    
    pub fn withEffect(
        id: []const u8,
        name: []const u8,
        description: []const u8,
        type_id: ItemType,
        texture_id: usize,
        value: u32,
        effect: ItemEffect,
        effect_value: i32
    ) Item {
        return .{
            .id = id,
            .name = name,
            .description = description,
            .type_id = type_id,
            .texture_id = texture_id,
            .value = value,
            .effect = effect,
            .effect_value = effect_value,
        };
    }
    
    pub fn asQuestItem(
        id: []const u8,
        name: []const u8,
        description: []const u8,
        texture_id: usize,
        quest_id: []const u8
    ) Item {
        return .{
            .id = id,
            .name = name,
            .description = description,
            .type_id = .QuestItem,
            .texture_id = texture_id,
            .value = 0,
            .quest_id = quest_id,
        };
    }
    
    pub fn asStackable(
        id: []const u8,
        name: []const u8,
        description: []const u8,
        type_id: ItemType,
        texture_id: usize,
        value: u32,
        max_stack: u32
    ) Item {
        return .{
            .id = id,
            .name = name,
            .description = description,
            .type_id = type_id,
            .texture_id = texture_id,
            .value = value,
            .stackable = true,
            .max_stack = max_stack,
        };
    }
};

pub const InventorySlot = struct {
    item_id: ?[]const u8,
    count: u32,
    
    pub fn init() InventorySlot {
        return .{
            .item_id = null,
            .count = 0,
        };
    }
    
    pub fn withItem(item_id: []const u8, count: u32) InventorySlot {
        return .{
            .item_id = item_id,
            .count = count,
        };
    }
    
    pub fn isEmpty(self: *const InventorySlot) bool {
        return self.item_id == null or self.count == 0;
    }
    
    pub fn canAddCount(self: *const InventorySlot, item: Item, amount: u32) bool {
        if (self.isEmpty()) return true;
        
        if (self.item_id) |id| {
            if (std.mem.eql(u8, id, item.id) and item.stackable) {
                return self.count + amount <= item.max_stack;
            }
        }
        
        return false;
    }
};

pub const EquipmentSlot = enum {
    Head,
    Chest,
    Legs,
    Feet,
    Weapon,
    Shield,
};

pub const Inventory = struct {
    allocator: std.mem.Allocator,
    capacity: usize,
    slots: []InventorySlot,
    gold: u32,
    equipment: std.StringHashMap(InventorySlot), // Use StringHashMap instead of EnumMap
    item_registry: *ItemRegistry,
    selected_slot: usize = 0,
    show_ui: bool = false,
    
    pub fn init(allocator: std.mem.Allocator, capacity: usize, item_registry: *ItemRegistry) !Inventory {
        const slots = try allocator.alloc(InventorySlot, capacity);
        
        for (slots) |*slot| {
            slot.* = InventorySlot.init();
        }
        
        return .{
            .allocator = allocator,
            .capacity = capacity,
            .slots = slots,
            .gold = 0,
            .equipment = std.StringHashMap(InventorySlot).init(allocator),
            .item_registry = item_registry,
        };
    }
    
    pub fn deinit(self: *Inventory) void {
        self.allocator.free(self.slots);
    }
    
    pub fn addItem(self: *Inventory, item_id: []const u8, count: u32) bool {
        const item = self.item_registry.getItem(item_id) orelse return false;
        var amount_left = count;
        
        // First try to stack with existing items
        if (item.stackable) {
            for (self.slots) |*slot| {
                if (slot.item_id) |id| {
                    if (std.mem.eql(u8, id, item_id)) {
                        const can_add = @min(amount_left, item.max_stack - slot.count);
                        slot.count += can_add;
                        amount_left -= can_add;
                        
                        if (amount_left == 0) return true;
                    }
                }
            }
        }
        
        // Then try to find empty slots
        for (self.slots) |*slot| {
            if (slot.isEmpty()) {
                const can_add = @min(amount_left, item.max_stack);
                slot.item_id = item_id;
                slot.count = can_add;
                amount_left -= can_add;
                
                if (amount_left == 0) return true;
            }
        }
        
        // Couldn't fit everything
        return false;
    }
    
    pub fn removeItem(self: *Inventory, item_id: []const u8, count: u32) bool {
        var amount_left = count;
        
        for (self.slots) |*slot| {
            if (slot.item_id) |id| {
                if (std.mem.eql(u8, id, item_id)) {
                    const can_remove = @min(amount_left, slot.count);
                    slot.count -= can_remove;
                    amount_left -= can_remove;
                    
                    if (slot.count == 0) {
                        slot.item_id = null;
                    }
                    
                    if (amount_left == 0) return true;
                }
            }
        }
        
        // Couldn't remove all items
        return false;
    }
    
    pub fn hasItem(self: *Inventory, item_id: []const u8, count: u32) bool {
        var total_count: u32 = 0;
        
        for (self.slots) |slot| {
            if (slot.item_id) |id| {
                if (std.mem.eql(u8, id, item_id)) {
                    total_count += slot.count;
                    if (total_count >= count) return true;
                }
            }
        }
        
        return false;
    }
    
    pub fn getItemCount(self: *Inventory, item_id: []const u8) u32 {
        var total_count: u32 = 0;
        
        for (self.slots) |slot| {
            if (slot.item_id) |id| {
                if (std.mem.eql(u8, id, item_id)) {
                    total_count += slot.count;
                }
            }
        }
        
        return total_count;
    }
    
    pub fn equipItem(self: *Inventory, slot_index: usize, equipment_slot_name: []const u8) bool {
        if (slot_index >= self.capacity) return false;
        
        const slot = &self.slots[slot_index];
        if (slot.isEmpty()) return false;
        
        const item_id = slot.item_id orelse return false;
        const item = self.item_registry.getItem(item_id) orelse return false;
        
        // Check if item can be equipped in this slot (using strings now)
        var can_equip = false;
        if (std.mem.eql(u8, equipment_slot_name, "Head") or 
            std.mem.eql(u8, equipment_slot_name, "Chest") or 
            std.mem.eql(u8, equipment_slot_name, "Legs") or 
            std.mem.eql(u8, equipment_slot_name, "Feet")) {
            can_equip = item.type_id == .Armor;
        } else if (std.mem.eql(u8, equipment_slot_name, "Weapon")) {
            can_equip = item.type_id == .Weapon;
        } else if (std.mem.eql(u8, equipment_slot_name, "Shield")) {
            can_equip = item.type_id == .Armor; // For simplicity
        }
        
        if (!can_equip) return false;
        
        // Unequip current item if any
        if (self.equipment.get(equipment_slot_name)) |equipped_slot| {
            if (!equipped_slot.isEmpty()) {
                // Add the currently equipped item back to inventory
                _ = self.addItem(equipped_slot.item_id.?, equipped_slot.count);
            }
        }
        
        // Equip the new item
        self.equipment.put(equipment_slot_name, InventorySlot.withItem(item_id, 1)) catch return false;
        
        // Remove from inventory
        slot.count -= 1;
        if (slot.count == 0) {
            slot.item_id = null;
        }
        
        return true;
    }
    
    pub fn unequipItem(self: *Inventory, equipment_slot_name: []const u8) bool {
        if (self.equipment.getPtr(equipment_slot_name)) |equipped_slot| {
            if (equipped_slot.isEmpty()) return false;
            
            // Add back to inventory
            if (self.addItem(equipped_slot.item_id.?, equipped_slot.count)) {
                // Clear equipment slot
                equipped_slot.* = InventorySlot.init();
                return true;
            }
        }
        
        return false;
    }
    
    pub fn useItem(self: *Inventory, slot_index: usize) ?ItemEffect {
        if (slot_index >= self.capacity) return null;
        
        const slot = &self.slots[slot_index];
        if (slot.isEmpty()) return null;
        
        const item_id = slot.item_id orelse return null;
        const item = self.item_registry.getItem(item_id) orelse return null;
        
        // Only consumable items can be used directly
        if (item.type_id != .Consumable) return null;
        
        // Remove one item from the stack
        slot.count -= 1;
        if (slot.count == 0) {
            slot.item_id = null;
        }
        
        return item.effect;
    }
    
    pub fn selectNextSlot(self: *Inventory) void {
        self.selected_slot = (self.selected_slot + 1) % self.capacity;
    }
    
    pub fn selectPrevSlot(self: *Inventory) void {
        if (self.selected_slot == 0) {
            self.selected_slot = self.capacity - 1;
        } else {
            self.selected_slot -= 1;
        }
    }
    
    pub fn toggleUI(self: *Inventory) void {
        self.show_ui = !self.show_ui;
    }
    
    pub fn render(self: *Inventory) void {
        // Always render hotbar
        self.renderHotbar();
        
        // Render full inventory UI if enabled
        if (self.show_ui) {
            self.renderInventoryUI();
        }
    }
    
    pub fn renderHotbar(self: *Inventory) void {
        const screen_width = c.GetScreenWidth();
        const screen_height = c.GetScreenHeight();
        
        const hotbar_slots = @min(self.capacity, 10);
        const slot_size: i32 = 50;
        const slot_padding: i32 = 5;
        const hotbar_width = (slot_size + slot_padding) * @as(i32, @intCast(hotbar_slots)) - slot_padding;
        
        const hotbar_x = @divTrunc(screen_width - hotbar_width, 2);
        const hotbar_y = screen_height - slot_size - 10;
        
        // Draw hotbar background
        c.DrawRectangle(
            hotbar_x - 5, 
            hotbar_y - 5, 
            hotbar_width + 10, 
            slot_size + 10, 
            c.ColorAlpha(c.BLACK, 0.7)
        );
        
        // Draw individual slots
        for (0..hotbar_slots) |i| {
            const slot_x = hotbar_x + @as(i32, @intCast(i)) * (slot_size + slot_padding);
            const slot_color = if (i == self.selected_slot) c.ColorAlpha(c.WHITE, 0.5) else c.ColorAlpha(c.GRAY, 0.5);
            
            // Draw slot background
            c.DrawRectangle(slot_x, hotbar_y, slot_size, slot_size, slot_color);
            c.DrawRectangleLines(slot_x, hotbar_y, slot_size, slot_size, c.WHITE);
            
            // Draw item if exists
            const slot = self.slots[i];
            if (!slot.isEmpty()) {
                if (slot.item_id) |item_id| {
                    if (self.item_registry.getItem(item_id)) |item| {
                        // Draw item with color based on type
                        const item_color = switch (item.type_id) {
                            .Consumable => c.GREEN,
                            .Weapon => c.RED,
                            .Armor => c.BLUE,
                            .QuestItem => c.PURPLE,
                            .Key => c.YELLOW,
                        };
                        
                        // Draw item representation
                        if (item.texture_id > 0 and item.texture_id < self.item_registry.textures.len) {
                            const texture = self.item_registry.textures[item.texture_id];
                            if (texture.id > 0) {
                                const source_rect = c.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(texture.width), .height = @floatFromInt(texture.height) };
                                const dest_rect = c.Rectangle{ .x = @floatFromInt(slot_x + 5), .y = @floatFromInt(hotbar_y + 5), .width = @floatFromInt(slot_size - 10), .height = @floatFromInt(slot_size - 10) };
                                c.DrawTexturePro(texture, source_rect, dest_rect, c.Vector2{ .x = 0, .y = 0 }, 0.0, c.WHITE);
                            } else {
                                c.DrawRectangle(slot_x + 5, hotbar_y + 5, slot_size - 10, slot_size - 10, item_color);
                            }
                        } else {
                            c.DrawRectangle(slot_x + 5, hotbar_y + 5, slot_size - 10, slot_size - 10, item_color);
                        }
                        
                        // Draw item count if more than 1
                        if (slot.count > 1) {
                            const count_text = std.fmt.allocPrint(self.allocator, "{d}", .{slot.count}) catch continue;
                            defer self.allocator.free(count_text);
                            
                            c.DrawText(@ptrCast(count_text), slot_x + slot_size - 15, hotbar_y + slot_size - 20, 16, c.WHITE);
                        }
                    }
                }
            }
        }
    }
    
    fn renderInventoryUI(self: *Inventory) void {
        const screen_width = c.GetScreenWidth();
        const screen_height = c.GetScreenHeight();
        
        const slots_per_row: usize = 10;
        const slot_size: i32 = 50;
        const slot_padding: i32 = 5;
        const rows = (self.capacity + slots_per_row - 1) / slots_per_row;
        
        const inventory_width = (slot_size + slot_padding) * @as(i32, @intCast(slots_per_row)) - slot_padding;
        const inventory_height = (slot_size + slot_padding) * @as(i32, @intCast(rows)) + 30; // Extra space for header
        
        const inventory_x = @divTrunc(screen_width - inventory_width, 2);
        const inventory_y = @divTrunc(screen_height - inventory_height, 2);
        
        // Draw inventory background
        c.DrawRectangle(
            inventory_x - 10, 
            inventory_y - 10, 
            inventory_width + 20, 
            inventory_height + 20, 
            c.ColorAlpha(c.BLACK, 0.9)
        );
        c.DrawRectangleLines(
            inventory_x - 10, 
            inventory_y - 10, 
            inventory_width + 20, 
            inventory_height + 20, 
            c.WHITE
        );
        
        // Draw inventory header
        c.DrawText("Inventory", inventory_x, inventory_y, 20, c.WHITE);
        c.DrawText(
            @ptrCast(std.fmt.allocPrint(self.allocator, "Gold: {d}", .{self.gold}) catch "Gold: ?"), 
            inventory_x + inventory_width - 100, 
            inventory_y, 
            20, 
            c.GOLD
        );
        
        // Draw individual slots
        for (0..self.capacity) |i| {
            const row = i / slots_per_row;
            const col = i % slots_per_row;
            
            const slot_x = inventory_x + @as(i32, @intCast(col)) * (slot_size + slot_padding);
            const slot_y = inventory_y + 30 + @as(i32, @intCast(row)) * (slot_size + slot_padding);
            
            // Draw slot background
            const slot_color = if (i == self.selected_slot) c.ColorAlpha(c.WHITE, 0.5) else c.ColorAlpha(c.GRAY, 0.5);
            c.DrawRectangle(slot_x, slot_y, slot_size, slot_size, slot_color);
            c.DrawRectangleLines(slot_x, slot_y, slot_size, slot_size, c.WHITE);
            
            // Draw item if exists (similar to hotbar rendering)
            const slot = self.slots[i];
            if (!slot.isEmpty()) {
                if (slot.item_id) |item_id| {
                    if (self.item_registry.getItem(item_id)) |item| {
                        // Draw item with color based on type
                        const item_color = switch (item.type_id) {
                            .Consumable => c.GREEN,
                            .Weapon => c.RED,
                            .Armor => c.BLUE,
                            .QuestItem => c.PURPLE,
                            .Key => c.YELLOW,
                        };
                        
                        // Draw item representation
                        c.DrawRectangle(slot_x + 5, slot_y + 5, slot_size - 10, slot_size - 10, item_color);
                        
                        // Draw item count if more than 1
                        if (slot.count > 1) {
                            const count_text = std.fmt.allocPrint(self.allocator, "{d}", .{slot.count}) catch continue;
                            defer self.allocator.free(count_text);
                            
                            c.DrawText(@ptrCast(count_text), slot_x + slot_size - 15, slot_y + slot_size - 20, 16, c.WHITE);
                        }
                    }
                }
            }
        }
        
        // Draw selected item details
        const selected_slot = self.slots[self.selected_slot];
        if (!selected_slot.isEmpty()) {
            if (selected_slot.item_id) |item_id| {
                if (self.item_registry.getItem(item_id)) |item| {
                    const detail_x = inventory_x;
                    const detail_y = inventory_y + inventory_height + 10;
                    
                    c.DrawRectangle(
                        detail_x - 10, 
                        detail_y - 10, 
                        inventory_width + 20, 
                        100, 
                        c.ColorAlpha(c.BLACK, 0.9)
                    );
                    c.DrawRectangleLines(
                        detail_x - 10, 
                        detail_y - 10, 
                        inventory_width + 20, 
                        100, 
                        c.WHITE
                    );
                    
                    c.DrawText(@ptrCast(item.name), detail_x, detail_y, 20, c.WHITE);
                    c.DrawText(@ptrCast(item.description), detail_x, detail_y + 25, 16, c.LIGHTGRAY);
                    
                    const value_text = std.fmt.allocPrint(self.allocator, "Value: {d}", .{item.value}) catch "Value: ?";
                    defer self.allocator.free(value_text);
                    c.DrawText(@ptrCast(value_text), detail_x, detail_y + 50, 16, c.GOLD);
                    
                    const type_text = std.fmt.allocPrint(self.allocator, "Type: {s}", .{@tagName(item.type_id)}) catch "Type: ?";
                    defer self.allocator.free(type_text);
                    c.DrawText(@ptrCast(type_text), detail_x, detail_y + 70, 16, c.LIGHTGRAY);
                }
            }
        }
    }
};

pub const ItemRegistry = struct {
    allocator: std.mem.Allocator,
    items: std.StringHashMap(Item),
    textures: []c.Texture2D,
    texture_count: usize,
    
    pub fn init(allocator: std.mem.Allocator, max_textures: usize) !ItemRegistry {
        const textures = try allocator.alloc(c.Texture2D, max_textures);
        
        return .{
            .allocator = allocator,
            .items = std.StringHashMap(Item).init(allocator),
            .textures = textures,
            .texture_count = 0,
        };
    }
    
    pub fn deinit(self: *ItemRegistry) void {
        self.items.deinit();
        
        // Unload all textures
        for (self.textures[0..self.texture_count]) |texture| {
            c.UnloadTexture(texture);
        }
        
        self.allocator.free(self.textures);
    }
    
    pub fn registerItem(self: *ItemRegistry, item: Item) !void {
        try self.items.put(item.id, item);
    }
    
    pub fn getItem(self: *ItemRegistry, id: []const u8) ?Item {
        return self.items.get(id);
    }
    
    pub fn loadTexture(self: *ItemRegistry, path: []const u8) !usize {
        if (self.texture_count >= self.textures.len) {
            return error.TextureArrayFull;
        }
        
        self.textures[self.texture_count] = c.LoadTexture(@ptrCast(path));
        const index = self.texture_count;
        self.texture_count += 1;
        return index;
    }
    
    pub fn loadDefaultItems(self: *ItemRegistry) !void {
        // Register some basic items
        try self.registerItem(Item.withEffect(
            "potion_health",
            "Health Potion",
            "Restores 20 health points.",
            .Consumable,
            0, // Texture ID
            10, // Value
            .Heal,
            20 // Effect value
        ));
        
        try self.registerItem(Item.withEffect(
            "potion_mana",
            "Mana Potion",
            "Restores 15 mana points.",
            .Consumable,
            0, // Texture ID
            15, // Value
            .RestoreMana,
            15 // Effect value
        ));
        
        try self.registerItem(Item.asStackable(
            "gold_coin",
            "Gold Coin",
            "A shiny gold coin.",
            .Consumable, // Using consumable for stackable currency
            0, // Texture ID
            1, // Value
            9999 // Max stack
        ));
        
        try self.registerItem(Item.asQuestItem(
            "item_amulet",
            "Lost Amulet",
            "A beautiful amulet with a blue gem.",
            0, // Texture ID
            "lost_item" // Quest ID
        ));
        
        try self.registerItem(Item.withEffect(
            "sword_basic",
            "Basic Sword",
            "A simple iron sword.",
            .Weapon,
            0, // Texture ID
            25, // Value
            .DamageBoost,
            5 // Effect value
        ));
        
        try self.registerItem(Item.withEffect(
            "armor_basic",
            "Leather Armor",
            "Basic protection made of leather.",
            .Armor,
            0, // Texture ID
            30, // Value
            .DefenseBoost,
            3 // Effect value
        ));
    }
};
