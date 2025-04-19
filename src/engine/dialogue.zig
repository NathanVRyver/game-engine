const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const DialogueAction = enum {
    None,
    StartQuest,
    GiveItem,
    SetFlag,
    TeleportPlayer,
};

pub const DialogueActionData = union(enum) {
    start_quest: []const u8, // Quest ID
    give_item: []const u8,   // Item ID
    set_flag: struct {
        flag_name: []const u8,
        value: bool,
    },
    teleport_player: struct {
        map_id: []const u8,
        x: i32,
        y: i32,
    },
    none: void,
};

pub const DialogueOption = struct {
    text: []const u8,
    next_node_id: []const u8,
    condition: ?struct {
        flag_name: []const u8,
        value: bool,
    },
    action: DialogueAction = .None,
    action_data: DialogueActionData = .{ .none = {} },

    pub fn init(text: []const u8, next_node_id: []const u8) DialogueOption {
        return .{
            .text = text,
            .next_node_id = next_node_id,
            .condition = null,
        };
    }

    pub fn withCondition(
        text: []const u8, 
        next_node_id: []const u8, 
        flag_name: []const u8, 
        value: bool
    ) DialogueOption {
        return .{
            .text = text,
            .next_node_id = next_node_id,
            .condition = .{
                .flag_name = flag_name,
                .value = value,
            },
        };
    }

    pub fn withAction(
        text: []const u8, 
        next_node_id: []const u8, 
        action: DialogueAction, 
        action_data: DialogueActionData
    ) DialogueOption {
        return .{
            .text = text,
            .next_node_id = next_node_id,
            .condition = null,
            .action = action,
            .action_data = action_data,
        };
    }
};

pub const DialogueNode = struct {
    id: []const u8,
    speaker: []const u8,
    text: []const u8,
    options: std.ArrayList(DialogueOption),
    
    pub fn init(allocator: std.mem.Allocator, id: []const u8, speaker: []const u8, text: []const u8) DialogueNode {
        return .{
            .id = id,
            .speaker = speaker,
            .text = text,
            .options = std.ArrayList(DialogueOption).init(allocator),
        };
    }
    
    pub fn deinit(self: *DialogueNode) void {
        self.options.deinit();
    }
    
    pub fn addOption(self: *DialogueNode, option: DialogueOption) !void {
        try self.options.append(option);
    }
};

pub const DialogueTree = struct {
    allocator: std.mem.Allocator,
    nodes: std.StringHashMap(DialogueNode),
    start_node_id: []const u8,
    
    pub fn init(allocator: std.mem.Allocator, start_node_id: []const u8) DialogueTree {
        return .{
            .allocator = allocator,
            .nodes = std.StringHashMap(DialogueNode).init(allocator),
            .start_node_id = start_node_id,
        };
    }
    
    pub fn deinit(self: *DialogueTree) void {
        var it = self.nodes.valueIterator();
        while (it.next()) |node| {
            node.deinit();
        }
        self.nodes.deinit();
    }
    
    pub fn addNode(self: *DialogueTree, node: DialogueNode) !void {
        try self.nodes.put(node.id, node);
    }
    
    pub fn getNode(self: *DialogueTree, id: []const u8) ?*DialogueNode {
        return self.nodes.getPtr(id);
    }
    
    pub fn getStartNode(self: *DialogueTree) ?*DialogueNode {
        return self.getNode(self.start_node_id);
    }
};

pub const DialogueSystem = struct {
    allocator: std.mem.Allocator,
    dialogues: std.StringHashMap(DialogueTree),
    active_dialogue: ?struct {
        tree_id: []const u8,
        current_node_id: []const u8,
        selected_option: usize,
    },
    
    pub fn init(allocator: std.mem.Allocator) DialogueSystem {
        return .{
            .allocator = allocator,
            .dialogues = std.StringHashMap(DialogueTree).init(allocator),
            .active_dialogue = null,
        };
    }
    
    pub fn deinit(self: *DialogueSystem) void {
        var it = self.dialogues.valueIterator();
        while (it.next()) |tree| {
            tree.deinit();
        }
        self.dialogues.deinit();
    }
    
    pub fn loadDialogue(self: *DialogueSystem, id: []const u8, filepath: []const u8) !void {
        _ = filepath;
        // TODO: Implement loading from file (e.g., JSON or TOML)
        
        // For now, create a test dialogue
        if (std.mem.eql(u8, id, "test_npc")) {
            var tree = DialogueTree.init(self.allocator, "greeting");
            
            var greeting = DialogueNode.init(self.allocator, "greeting", "Villager", "Hello, traveler! What brings you to our village?");
            try greeting.addOption(DialogueOption.init("I'm looking for adventure", "quest"));
            try greeting.addOption(DialogueOption.init("Just passing through", "farewell"));
            try tree.addNode(greeting);
            
            var quest = DialogueNode.init(self.allocator, "quest", "Villager", "Ah, an adventurer! Would you help me with something?");
            try quest.addOption(DialogueOption.withAction(
                "Sure, what do you need?", 
                "quest_details",
                .StartQuest,
                .{ .start_quest = "lost_item" }
            ));
            try quest.addOption(DialogueOption.init("Not now", "farewell"));
            try tree.addNode(quest);
            
            var quest_details = DialogueNode.init(self.allocator, "quest_details", "Villager", "Great! I lost my lucky amulet in the forest. Can you find it for me?");
            try quest_details.addOption(DialogueOption.init("I'll look for it", "farewell"));
            try tree.addNode(quest_details);
            
            var farewell = DialogueNode.init(self.allocator, "farewell", "Villager", "Safe travels, friend!");
            try farewell.addOption(DialogueOption.init("Goodbye", "exit"));
            try tree.addNode(farewell);
            
            try self.dialogues.put(id, tree);
        }
    }
    
    pub fn startDialogue(self: *DialogueSystem, id: []const u8) bool {
        if (self.dialogues.getPtr(id)) |tree| {
            if (tree.getStartNode()) |_| {
                self.active_dialogue = .{
                    .tree_id = id,
                    .current_node_id = tree.start_node_id,
                    .selected_option = 0,
                };
                return true;
            }
        }
        return false;
    }
    
    pub fn endDialogue(self: *DialogueSystem) void {
        self.active_dialogue = null;
    }
    
    pub fn getCurrentNode(self: *DialogueSystem) ?*DialogueNode {
        if (self.active_dialogue) |active| {
            if (self.dialogues.getPtr(active.tree_id)) |tree| {
                return tree.getNode(active.current_node_id);
            }
        }
        return null;
    }
    
    pub fn selectNextOption(self: *DialogueSystem) void {
        if (self.active_dialogue) |*active| {
            if (self.getCurrentNode()) |node| {
                active.selected_option = (active.selected_option + 1) % node.options.items.len;
            }
        }
    }
    
    pub fn selectPrevOption(self: *DialogueSystem) void {
        if (self.active_dialogue) |*active| {
            if (self.getCurrentNode()) |node| {
                if (active.selected_option == 0) {
                    active.selected_option = node.options.items.len - 1;
                } else {
                    active.selected_option -= 1;
                }
            }
        }
    }
    
    pub fn executeSelectedOption(self: *DialogueSystem) ?DialogueOption {
        if (self.active_dialogue) |*active| {
            if (self.getCurrentNode()) |node| {
                if (active.selected_option < node.options.items.len) {
                    const option = node.options.items[active.selected_option];
                    
                    // Handle special "exit" node
                    if (std.mem.eql(u8, option.next_node_id, "exit")) {
                        self.endDialogue();
                        return option;
                    }
                    
                    // Otherwise, move to the next node
                    active.current_node_id = option.next_node_id;
                    active.selected_option = 0;
                    return option;
                }
            }
        }
        return null;
    }
    
    pub fn render(self: *DialogueSystem) void {
        if (self.getCurrentNode()) |node| {
            // Draw dialogue box
            const screen_width = c.GetScreenWidth();
            const screen_height = c.GetScreenHeight();
            
            const box_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(screen_width)) * 0.8));
            const box_height = @as(i32, @intFromFloat(@as(f32, @floatFromInt(screen_height)) * 0.3));
            const box_x = @divTrunc(screen_width - box_width, 2);
            const box_y = screen_height - box_height - 20;
            
            // Draw dialogue background
            c.DrawRectangle(box_x, box_y, box_width, box_height, c.ColorAlpha(c.BLACK, 0.8));
            c.DrawRectangleLines(box_x, box_y, box_width, box_height, c.WHITE);
            
            // Draw speaker name
            c.DrawText(
                @ptrCast(node.speaker), 
                box_x + 20, 
                box_y + 15, 
                20, 
                c.YELLOW
            );
            
            // Draw dialogue text
            c.DrawText(
                @ptrCast(node.text), 
                box_x + 20, 
                box_y + 45, 
                16, 
                c.WHITE
            );
            
            // Draw options
            const option_start_y = box_y + 100;
            const option_height = 24;
            
            if (self.active_dialogue) |active| {
                for (node.options.items, 0..) |option, i| {
                    const option_color = if (i == active.selected_option) c.GREEN else c.WHITE;
                    const option_text = option.text;
                    
                    c.DrawText(
                        @ptrCast(option_text), 
                        box_x + 30, 
                        option_start_y + @as(i32, @intCast(i)) * option_height, 
                        16, 
                        option_color
                    );
                }
            }
        }
    }
};
