const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const EntityType = enum {
    Player,
    NPC,
    Item,
    Trigger,
};

pub const ComponentType = enum {
    Transform,
    Sprite,
    Collider,
    Health,
    Dialogue,
    QuestGiver,
    Inventory,
};

pub const Component = struct {
    type_id: ComponentType,
    data: *anyopaque,
    deinit_fn: *const fn(*anyopaque) void,
};

pub const Transform = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    
    pub fn init(x: f32, y: f32, width: f32, height: f32) Transform {
        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }
    
    pub fn deinit(_: *Transform) void {}
};

pub const Sprite = struct {
    texture: c.Texture2D,
    color: c.Color,
    
    pub fn init(texture: c.Texture2D, color: c.Color) Sprite {
        return .{
            .texture = texture,
            .color = color,
        };
    }
    
    pub fn deinit(_: *Sprite) void {
        // In a real implementation, we might unload the texture here
        // But since textures are often shared, we'll handle this separately
    }
};

pub const Collider = struct {
    is_solid: bool,
    
    pub fn init(is_solid: bool) Collider {
        return .{
            .is_solid = is_solid,
        };
    }
    
    pub fn deinit(_: *Collider) void {}
};

pub const Entity = struct {
    id: u64,
    type_id: EntityType,
    name: []const u8,
    is_active: bool,
    components: std.ArrayList(Component),
    
    pub fn init(allocator: std.mem.Allocator, id: u64, type_id: EntityType, name: []const u8) Entity {
        return .{
            .id = id,
            .type_id = type_id,
            .name = name,
            .is_active = true,
            .components = std.ArrayList(Component).init(allocator),
        };
    }
    
    pub fn deinit(self: *Entity) void {
        for (self.components.items) |component| {
            component.deinit_fn(component.data);
        }
        self.components.deinit();
    }
    
    pub fn addComponent(self: *Entity, comptime T: type, component_type: ComponentType, data: *T) !void {
        const deinitFn = struct {
            fn wrapper(ptr: *anyopaque) void {
                const typed_ptr = @as(*T, @ptrCast(@alignCast(ptr)));
                typed_ptr.deinit();
            }
        }.wrapper;
        
        try self.components.append(.{
            .type_id = component_type,
            .data = @ptrCast(data),
            .deinit_fn = deinitFn,
        });
    }
    
    pub fn getComponent(self: *Entity, component_type: ComponentType) ?*anyopaque {
        for (self.components.items) |component| {
            if (component.type_id == component_type) {
                return component.data;
            }
        }
        return null;
    }
    
    pub fn hasComponent(self: *Entity, component_type: ComponentType) bool {
        for (self.components.items) |component| {
            if (component.type_id == component_type) {
                return true;
            }
        }
        return false;
    }
    
    pub fn removeComponent(self: *Entity, component_type: ComponentType) bool {
        for (self.components.items, 0..) |component, i| {
            if (component.type_id == component_type) {
                // Call the deinit function on the component
                component.deinit_fn(component.data);
                
                // Remove from the list
                _ = self.components.orderedRemove(i);
                return true;
            }
        }
        return false;
    }
};

// Entity manager to handle creation and tracking of entities
pub const EntityManager = struct {
    allocator: std.mem.Allocator,
    entities: std.ArrayList(Entity),
    next_id: u64,
    
    pub fn init(allocator: std.mem.Allocator) EntityManager {
        return .{
            .allocator = allocator,
            .entities = std.ArrayList(Entity).init(allocator),
            .next_id = 0,
        };
    }
    
    pub fn deinit(self: *EntityManager) void {
        for (self.entities.items) |*entity| {
            entity.deinit();
        }
        self.entities.deinit();
    }
    
    pub fn createEntity(self: *EntityManager, type_id: EntityType, name: []const u8) !*Entity {
        const id = self.next_id;
        self.next_id += 1;
        
        try self.entities.append(Entity.init(self.allocator, id, type_id, name));
        return &self.entities.items[self.entities.items.len - 1];
    }
    
    pub fn removeEntity(self: *EntityManager, id: u64) bool {
        for (self.entities.items, 0..) |entity, i| {
            if (entity.id == id) {
                var e = self.entities.orderedRemove(i);
                e.deinit();
                return true;
            }
        }
        return false;
    }
    
    pub fn getEntity(self: *EntityManager, id: u64) ?*Entity {
        for (self.entities.items) |*entity| {
            if (entity.id == id) {
                return entity;
            }
        }
        return null;
    }
    
    pub fn update(_: *EntityManager) void {
        // This would typically implement game logic for all entities
        // For now, it's a placeholder for future functionality
    }
    
    pub fn render(self: *EntityManager) void {
        // Render all entities with sprite components
        for (self.entities.items) |*entity| {
            if (!entity.is_active) continue;
            
            if (entity.hasComponent(ComponentType.Transform) and entity.hasComponent(ComponentType.Sprite)) {
                const transform_ptr = entity.getComponent(ComponentType.Transform) orelse continue;
                const sprite_ptr = entity.getComponent(ComponentType.Sprite) orelse continue;
                
                const transform = @as(*Transform, @ptrCast(@alignCast(transform_ptr))).*;
                const sprite = @as(*Sprite, @ptrCast(@alignCast(sprite_ptr))).*;
                
                // Draw the entity
                if (sprite.texture.id > 0) {
                    // If it has a texture, draw that
                    const source_rect = c.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(sprite.texture.width), .height = @floatFromInt(sprite.texture.height) };
                    const dest_rect = c.Rectangle{ .x = transform.x, .y = transform.y, .width = transform.width, .height = transform.height };
                    c.DrawTexturePro(sprite.texture, source_rect, dest_rect, c.Vector2{ .x = 0, .y = 0 }, 0.0, c.WHITE);
                } else {
                    // Otherwise, just draw a colored rectangle
                    c.DrawRectangle(
                        @intFromFloat(transform.x),
                        @intFromFloat(transform.y),
                        @intFromFloat(transform.width),
                        @intFromFloat(transform.height),
                        sprite.color
                    );
                }
            }
        }
    }
};
