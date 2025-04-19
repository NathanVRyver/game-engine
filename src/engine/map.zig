const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

// Tile map structures and functions
pub const TileType = enum {
    Empty,
    Floor,
    Wall,
    Door,
    Water,
};

pub const Tile = struct {
    type_id: TileType,
    texture_id: usize,
    is_solid: bool,
    
    pub fn init(type_id: TileType, texture_id: usize, is_solid: bool) Tile {
        return .{
            .type_id = type_id,
            .texture_id = texture_id,
            .is_solid = is_solid,
        };
    }
};

pub const Layer = struct {
    name: []const u8,
    tiles: []Tile,
    visible: bool,
    width: usize,
    height: usize,
    
    pub fn init(allocator: std.mem.Allocator, name: []const u8, width: usize, height: usize) !Layer {
        const tiles = try allocator.alloc(Tile, width * height);
        
        for (tiles) |*tile| {
            tile.* = Tile.init(TileType.Empty, 0, false);
        }
        
        return .{
            .name = name,
            .tiles = tiles,
            .visible = true,
            .width = width,
            .height = height,
        };
    }
    
    pub fn deinit(self: *Layer, allocator: std.mem.Allocator) void {
        allocator.free(self.tiles);
    }
    
    pub fn getTile(self: *Layer, x: usize, y: usize) *Tile {
        return &self.tiles[y * self.width + x];
    }
    
    pub fn setTile(self: *Layer, x: usize, y: usize, tile: Tile) void {
        self.tiles[y * self.width + x] = tile;
    }
};

pub const Map = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    width: usize,
    height: usize,
    tile_size: usize,
    layers: std.ArrayList(Layer),
    tile_textures: []c.Texture2D,
    texture_count: usize,
    
    pub fn init(allocator: std.mem.Allocator, name: []const u8, width: usize, height: usize, tile_size: usize, max_textures: usize) !Map {
        const tile_textures = try allocator.alloc(c.Texture2D, max_textures);
        
        return .{
            .allocator = allocator,
            .name = name,
            .width = width,
            .height = height,
            .tile_size = tile_size,
            .layers = std.ArrayList(Layer).init(allocator),
            .tile_textures = tile_textures,
            .texture_count = 0,
        };
    }
    
    pub fn deinit(self: *Map) void {
        for (self.layers.items) |*layer| {
            layer.deinit(self.allocator);
        }
        self.layers.deinit();
        
        // Unload all textures
        for (self.tile_textures[0..self.texture_count]) |texture| {
            c.UnloadTexture(texture);
        }
        
        self.allocator.free(self.tile_textures);
    }
    
    pub fn addLayer(self: *Map, name: []const u8) !void {
        const layer = try Layer.init(self.allocator, name, self.width, self.height);
        try self.layers.append(layer);
    }
    
    pub fn loadTexture(self: *Map, path: []const u8) !usize {
        if (self.texture_count >= self.tile_textures.len) {
            return error.TextureArrayFull;
        }
        
        self.tile_textures[self.texture_count] = c.LoadTexture(@ptrCast(path));
        const index = self.texture_count;
        self.texture_count += 1;
        return index;
    }
    
    pub fn isTileSolid(self: *Map, x: usize, y: usize) bool {
        // Check collision layer first
        if (self.getCollisionLayer()) |collision_layer| {
            if (x < self.width and y < self.height) {
                const tile = collision_layer.getTile(x, y);
                return tile.is_solid;
            }
        }
        return false;
    }
    
    pub fn getCollisionLayer(self: *Map) ?*Layer {
        // Find a layer named "collision"
        for (self.layers.items) |*layer| {
            if (std.mem.eql(u8, layer.name, "collision")) {
                return layer;
            }
        }
        return null;
    }
    
    pub fn render(self: *Map, camera_x: f32, camera_y: f32) void {
        // Calculate visible tile range
        const screen_width = c.GetScreenWidth();
        const screen_height = c.GetScreenHeight();
        
        const start_x = @max(0, @as(i32, @intFromFloat(camera_x / @as(f32, @floatFromInt(self.tile_size)))));
        const start_y = @max(0, @as(i32, @intFromFloat(camera_y / @as(f32, @floatFromInt(self.tile_size)))));
        
        const end_x = @min(
            @as(i32, @intCast(self.width)), 
            start_x + @as(i32, @intFromFloat(@as(f32, @floatFromInt(screen_width)) / @as(f32, @floatFromInt(self.tile_size)))) + 1
        );
        const end_y = @min(
            @as(i32, @intCast(self.height)), 
            start_y + @as(i32, @intFromFloat(@as(f32, @floatFromInt(screen_height)) / @as(f32, @floatFromInt(self.tile_size)))) + 1
        );
        
        // Draw each visible layer
        for (self.layers.items) |layer| {
            if (!layer.visible) continue;
            
            var y: i32 = start_y;
            while (y < end_y) : (y += 1) {
                var x: i32 = start_x;
                while (x < end_x) : (x += 1) {
                    var layer_mut = @constCast(&layer);
                    const tile = layer_mut.getTile(@intCast(x), @intCast(y));
                    if (tile.type_id == TileType.Empty) continue;
                    
                    const texture_id = tile.texture_id;
                    if (texture_id < self.texture_count) {
                        const texture = self.tile_textures[texture_id];
                        const screen_x = @as(f32, @floatFromInt(x * @as(i32, @intCast(self.tile_size)))) - camera_x;
                        const screen_y = @as(f32, @floatFromInt(y * @as(i32, @intCast(self.tile_size)))) - camera_y;
                        
                        const source_rect = c.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(texture.width), .height = @floatFromInt(texture.height) };
                        const dest_rect = c.Rectangle{ 
                            .x = screen_x, 
                            .y = screen_y, 
                            .width = @floatFromInt(self.tile_size), 
                            .height = @floatFromInt(self.tile_size) 
                        };
                        
                        c.DrawTexturePro(texture, source_rect, dest_rect, c.Vector2{ .x = 0, .y = 0 }, 0.0, c.WHITE);
                    } else {
                        // Fallback: draw colored rectangles for different tile types
                        const screen_x = @as(f32, @floatFromInt(x * @as(i32, @intCast(self.tile_size)))) - camera_x;
                        const screen_y = @as(f32, @floatFromInt(y * @as(i32, @intCast(self.tile_size)))) - camera_y;
                        
                        const color = switch (tile.type_id) {
                            .Empty => c.WHITE,
                            .Floor => c.BEIGE,
                            .Wall => c.GRAY,
                            .Door => c.BROWN,
                            .Water => c.BLUE,
                        };
                        
                        c.DrawRectangle(
                            @intFromFloat(screen_x),
                            @intFromFloat(screen_y),
                            @intCast(self.tile_size),
                            @intCast(self.tile_size),
                            color
                        );
                    }
                }
            }
        }
    }

    // Simple map serialization/deserialization functions to be implemented
    pub fn loadFromFile(allocator: std.mem.Allocator, filepath: []const u8) !Map {
        _ = filepath;
        // TODO: Implement loading from file (e.g., JSON or TOML)
        // For now, return a simple test map
        var map = try Map.init(allocator, "test_map", 20, 20, 32, 10);
        try map.addLayer("background");
        try map.addLayer("collision");
        
        // Set up some test tiles
        var bg_layer = &map.layers.items[0];
        var collision_layer = &map.layers.items[1];
        
        // Create walls around the edges
        for (0..map.width) |x| {
            for (0..map.height) |y| {
                if (x == 0 or y == 0 or x == map.width - 1 or y == map.height - 1) {
                    // Wall
                    bg_layer.setTile(x, y, Tile.init(TileType.Wall, 0, true));
                    collision_layer.setTile(x, y, Tile.init(TileType.Wall, 0, true));
                } else {
                    // Floor
                    bg_layer.setTile(x, y, Tile.init(TileType.Floor, 0, false));
                    collision_layer.setTile(x, y, Tile.init(TileType.Empty, 0, false));
                }
            }
        }
        
        return map;
    }
    
    pub fn saveToFile(self: *Map, filepath: []const u8) !void {
        _ = filepath;
        _ = self;
        // TODO: Implement saving to file (e.g., JSON or TOML)
    }
};