const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const QuestStatus = enum {
    NotStarted,
    Active,
    Completed,
    Failed,
};

pub const QuestType = enum {
    Main,
    Side,
};

pub const QuestObjectiveType = enum {
    CollectItem,
    KillEnemy,
    ReachLocation,
    TalkToNPC,
    Custom,
};

pub const QuestObjective = struct {
    id: []const u8,
    description: []const u8,
    type_id: QuestObjectiveType,
    target_id: []const u8,
    required_count: u32,
    current_count: u32 = 0,
    completed: bool = false,
    
    pub fn init(
        id: []const u8, 
        description: []const u8, 
        type_id: QuestObjectiveType, 
        target_id: []const u8, 
        required_count: u32
    ) QuestObjective {
        return .{
            .id = id,
            .description = description,
            .type_id = type_id,
            .target_id = target_id,
            .required_count = required_count,
            .current_count = 0,
            .completed = false,
        };
    }
    
    pub fn update(self: *QuestObjective, count: u32) bool {
        self.current_count = @min(self.current_count + count, self.required_count);
        self.completed = self.current_count >= self.required_count;
        return self.completed;
    }
    
    pub fn getProgress(self: *QuestObjective) f32 {
        return @as(f32, @floatFromInt(self.current_count)) / @as(f32, @floatFromInt(self.required_count));
    }
};

pub const QuestReward = struct {
    item_id: ?[]const u8 = null,
    gold: u32 = 0,
    experience: u32 = 0,
    flag_name: ?[]const u8 = null,
    
    pub fn init() QuestReward {
        return .{};
    }
    
    pub fn withItem(item_id: []const u8) QuestReward {
        return .{
            .item_id = item_id,
        };
    }
    
    pub fn withGold(gold: u32) QuestReward {
        return .{
            .gold = gold,
        };
    }
    
    pub fn withExperience(experience: u32) QuestReward {
        return .{
            .experience = experience,
        };
    }
    
    pub fn withFlag(flag_name: []const u8) QuestReward {
        return .{
            .flag_name = flag_name,
        };
    }
};

pub const Quest = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
    type_id: QuestType,
    status: QuestStatus,
    objectives: std.ArrayList(QuestObjective),
    rewards: std.ArrayList(QuestReward),
    
    pub fn init(
        allocator: std.mem.Allocator, 
        id: []const u8, 
        title: []const u8, 
        description: []const u8, 
        type_id: QuestType
    ) Quest {
        return .{
            .id = id,
            .title = title,
            .description = description,
            .type_id = type_id,
            .status = .NotStarted,
            .objectives = std.ArrayList(QuestObjective).init(allocator),
            .rewards = std.ArrayList(QuestReward).init(allocator),
        };
    }
    
    pub fn deinit(self: *Quest) void {
        self.objectives.deinit();
        self.rewards.deinit();
    }
    
    pub fn addObjective(self: *Quest, objective: QuestObjective) !void {
        try self.objectives.append(objective);
    }
    
    pub fn addReward(self: *Quest, reward: QuestReward) !void {
        try self.rewards.append(reward);
    }
    
    pub fn start(self: *Quest) void {
        if (self.status == .NotStarted) {
            self.status = .Active;
        }
    }
    
    pub fn complete(self: *Quest) void {
        if (self.status == .Active) {
            self.status = .Completed;
        }
    }
    
    pub fn fail(self: *Quest) void {
        if (self.status == .Active) {
            self.status = .Failed;
        }
    }
    
    pub fn updateObjective(self: *Quest, objective_id: []const u8, count: u32) bool {
        for (self.objectives.items) |*objective| {
            if (std.mem.eql(u8, objective.id, objective_id)) {
                return objective.update(count);
            }
        }
        return false;
    }
    
    pub fn checkCompletion(self: *Quest) bool {
        if (self.status != .Active) return false;
        
        for (self.objectives.items) |objective| {
            if (!objective.completed) {
                return false;
            }
        }
        
        // All objectives completed
        self.complete();
        return true;
    }
    
    pub fn getObjectiveByID(self: *Quest, objective_id: []const u8) ?*QuestObjective {
        for (self.objectives.items) |*objective| {
            if (std.mem.eql(u8, objective.id, objective_id)) {
                return objective;
            }
        }
        return null;
    }
};

pub const QuestSystem = struct {
    allocator: std.mem.Allocator,
    quests: std.StringHashMap(Quest),
    active_quest_id: ?[]const u8,
    
    pub fn init(allocator: std.mem.Allocator) QuestSystem {
        return .{
            .allocator = allocator,
            .quests = std.StringHashMap(Quest).init(allocator),
            .active_quest_id = null,
        };
    }
    
    pub fn deinit(self: *QuestSystem) void {
        var it = self.quests.valueIterator();
        while (it.next()) |quest| {
            quest.deinit();
        }
        self.quests.deinit();
    }
    
    pub fn loadQuest(self: *QuestSystem, id: []const u8, filepath: []const u8) !void {
        _ = filepath;
        // TODO: Implement loading from file (e.g., JSON or TOML)
        
        // For now, create a test quest
        if (std.mem.eql(u8, id, "lost_item")) {
            var quest = Quest.init(
                self.allocator, 
                "lost_item", 
                "The Lost Amulet", 
                "Find the villager's lost amulet in the forest.", 
                .Side
            );
            
            try quest.addObjective(QuestObjective.init(
                "find_amulet", 
                "Find the lost amulet", 
                .CollectItem, 
                "item_amulet", 
                1
            ));
            
            try quest.addObjective(QuestObjective.init(
                "return_amulet", 
                "Return the amulet to the villager", 
                .TalkToNPC, 
                "npc_villager", 
                1
            ));
            
            try quest.addReward(QuestReward.withGold(50));
            try quest.addReward(QuestReward.withExperience(100));
            
            try self.quests.put(id, quest);
        }
    }
    
    pub fn startQuest(self: *QuestSystem, id: []const u8) bool {
        if (self.quests.getPtr(id)) |quest| {
            quest.start();
            return true;
        }
        return false;
    }
    
    pub fn completeQuest(self: *QuestSystem, id: []const u8) bool {
        if (self.quests.getPtr(id)) |quest| {
            quest.complete();
            return true;
        }
        return false;
    }
    
    pub fn failQuest(self: *QuestSystem, id: []const u8) bool {
        if (self.quests.getPtr(id)) |quest| {
            quest.fail();
            return true;
        }
        return false;
    }
    
    pub fn updateObjective(self: *QuestSystem, quest_id: []const u8, objective_id: []const u8, count: u32) bool {
        if (self.quests.getPtr(quest_id)) |quest| {
            const updated = quest.updateObjective(objective_id, count);
            if (updated) {
                _ = quest.checkCompletion();
            }
            return updated;
        }
        return false;
    }
    
    pub fn getQuest(self: *QuestSystem, id: []const u8) ?*Quest {
        return self.quests.getPtr(id);
    }
    
    pub fn getActiveQuests(self: *QuestSystem, allocator: std.mem.Allocator) !std.ArrayList(*Quest) {
        var active_quests = std.ArrayList(*Quest).init(allocator);
        
        var it = self.quests.valueIterator();
        while (it.next()) |quest| {
            if (quest.status == .Active) {
                try active_quests.append(quest);
            }
        }
        
        return active_quests;
    }
    
    pub fn setActiveQuest(self: *QuestSystem, id: ?[]const u8) void {
        self.active_quest_id = id;
    }
    
    pub fn getActiveQuest(self: *QuestSystem) ?*Quest {
        if (self.active_quest_id) |id| {
            return self.getQuest(id);
        }
        return null;
    }
    
    pub fn renderQuestLog(self: *QuestSystem) void {
        const screen_width = c.GetScreenWidth();
        const box_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(screen_width)) * 0.3));
        const box_x = screen_width - box_width - 20;
        const box_y = 60;
        
        // Get active quests
        var active_quests = self.getActiveQuests(self.allocator) catch return;
        defer active_quests.deinit();
        
        if (active_quests.items.len == 0) return;
        
        // Draw quest log header
        c.DrawRectangle(box_x, box_y, box_width, 30, c.ColorAlpha(c.BLACK, 0.8));
        c.DrawRectangleLines(box_x, box_y, box_width, 30, c.WHITE);
        c.DrawText("Quest Log", box_x + 10, box_y + 5, 20, c.YELLOW);
        
        // Draw active quests
        var y_offset: i32 = box_y + 40;
        for (active_quests.items) |quest| {
            const quest_height: i32 = 30 + @as(i32, @intCast(quest.objectives.items.len)) * 25;
            
            // Draw quest background
            c.DrawRectangle(box_x, y_offset, box_width, quest_height, c.ColorAlpha(c.BLACK, 0.7));
            c.DrawRectangleLines(box_x, y_offset, box_width, quest_height, c.WHITE);
            
            // Draw quest title
            c.DrawText(
                @ptrCast(quest.title), 
                box_x + 10, 
                y_offset + 5, 
                18, 
                c.WHITE
            );
            
            // Draw objectives
            for (quest.objectives.items, 0..) |*objective, i| {
                const objective_color = if (objective.completed) c.GREEN else c.LIGHTGRAY;
                const progress_text = std.fmt.allocPrint(
                    self.allocator, 
                    "{s} ({d}/{d})", 
                    .{ objective.description, objective.current_count, objective.required_count }
                ) catch continue;
                defer self.allocator.free(progress_text);
                
                c.DrawText(
                    @ptrCast(progress_text), 
                    box_x + 20, 
                    y_offset + 30 + @as(i32, @intCast(i)) * 25, 
                    16, 
                    objective_color
                );
            }
            
            y_offset += quest_height + 10;
        }
    }
};