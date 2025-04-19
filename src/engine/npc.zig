const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const entity = @import("entity.zig");
const dialogue = @import("dialogue.zig");
const quest = @import("quest.zig");

pub const NPCState = enum {
    Idle,
    Roaming,
    TalkingToPlayer,
    Following,
};

pub const NPCBehavior = enum {
    Static,
    Patrol,
    RandomWalk,
};

pub const NPCType = enum {
    Villager,
    Merchant,
    QuestGiver,
    Guard,
};

pub const PatrolPoint = struct {
    x: f32,
    y: f32,
    wait_time: f32,
};


pub const DialogueComponent = struct {
    dialogue_id: []const u8,
    speaking: bool = false,
    
    pub fn init(dialogue_id: []const u8) DialogueComponent {
        return .{
            .dialogue_id = dialogue_id,
            .speaking = false,
        };
    }
    
    pub fn deinit(_: *DialogueComponent) void {}
};

pub const QuestGiverComponent = struct {
    quest_ids: std.ArrayList([]const u8),
    
    pub fn init(allocator: std.mem.Allocator) QuestGiverComponent {
        return .{
            .quest_ids = std.ArrayList([]const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *QuestGiverComponent) void {
        self.quest_ids.deinit();
    }
    
    pub fn addQuest(self: *QuestGiverComponent, quest_id: []const u8) !void {
        try self.quest_ids.append(quest_id);
    }
};

pub const NPCManager = struct {
    allocator: std.mem.Allocator,
    entity_manager: *entity.EntityManager,
    dialogue_system: *dialogue.DialogueSystem,
    quest_system: *quest.QuestSystem,
    player_entity_id: ?u64,
    interaction_radius: f32,
    
    pub fn init(
        allocator: std.mem.Allocator,
        entity_manager: *entity.EntityManager,
        dialogue_system: *dialogue.DialogueSystem,
        quest_system: *quest.QuestSystem
    ) NPCManager {
        return .{
            .allocator = allocator,
            .entity_manager = entity_manager,
            .dialogue_system = dialogue_system,
            .quest_system = quest_system,
            .player_entity_id = null,
            .interaction_radius = 40.0,
        };
    }
    
    pub fn deinit(_: *NPCManager) void {
    }
    
    pub fn setPlayerEntity(self: *NPCManager, player_id: u64) void {
        self.player_entity_id = player_id;
    }
    
    pub fn createNPC(
        self: *NPCManager,
        name: []const u8,
        x: f32,
        y: f32,
        npc_type: NPCType
    ) !u64 {
        const npc = try self.entity_manager.createEntity(entity.EntityType.NPC, name);
        
        // Add transform component
        var transform = entity.Transform.init(x, y, 32, 32);
        try npc.addComponent(entity.Transform, entity.ComponentType.Transform, &transform);
        
        // Add sprite component with color based on NPC type
        const color = switch (npc_type) {
            .Villager => c.GREEN,
            .Merchant => c.GOLD,
            .QuestGiver => c.PURPLE,
            .Guard => c.DARKBLUE,
        };
        
        var sprite = entity.Sprite.init(c.Texture2D{}, color);
        try npc.addComponent(entity.Sprite, entity.ComponentType.Sprite, &sprite);
        
        // Add collider component
        var collider = entity.Collider.init(true);
        try npc.addComponent(entity.Collider, entity.ComponentType.Collider, &collider);
        
        return npc.id;
    }
    
    pub fn addDialogueToNPC(self: *NPCManager, npc_id: u64, dialogue_id: []const u8) !void {
        if (self.entity_manager.getEntity(npc_id)) |npc| {
            // First make sure the dialogue exists and is loaded
            if (!self.dialogue_system.dialogues.contains(dialogue_id)) {
                try self.dialogue_system.loadDialogue(dialogue_id, "");
            }
            
            // Add dialogue component
            var dialogue_comp = DialogueComponent.init(dialogue_id);
            try npc.addComponent(DialogueComponent, entity.ComponentType.Dialogue, &dialogue_comp);
        }
    }
    
    pub fn addQuestToNPC(self: *NPCManager, npc_id: u64, quest_id: []const u8) !void {
        if (self.entity_manager.getEntity(npc_id)) |npc| {
            // First make sure the quest exists and is loaded
            if (!self.quest_system.quests.contains(quest_id)) {
                try self.quest_system.loadQuest(quest_id, "");
            }
            
            // Check if NPC already has a quest giver component
            if (npc.hasComponent(entity.ComponentType.QuestGiver)) {
                const comp_ptr = npc.getComponent(entity.ComponentType.QuestGiver) orelse return;
                const quest_giver = @as(*QuestGiverComponent, @ptrCast(@alignCast(comp_ptr)));
                try quest_giver.addQuest(quest_id);
            } else {
                // Add a new quest giver component
                var quest_giver = QuestGiverComponent.init(self.allocator);
                try quest_giver.addQuest(quest_id);
                try npc.addComponent(QuestGiverComponent, entity.ComponentType.QuestGiver, &quest_giver);
            }
        }
    }
    
    pub fn interact(self: *NPCManager, npc_id: u64) bool {
        if (self.entity_manager.getEntity(npc_id)) |npc| {
            // Check if NPC has dialogue
            if (npc.hasComponent(entity.ComponentType.Dialogue)) {
                const comp_ptr = npc.getComponent(entity.ComponentType.Dialogue) orelse return false;
                const dialogue_comp = @as(*DialogueComponent, @ptrCast(@alignCast(comp_ptr)));
                
                // Start dialogue
                dialogue_comp.speaking = true;
                return self.dialogue_system.startDialogue(dialogue_comp.dialogue_id);
            }
        }
        return false;
    }
    
    pub fn checkPlayerInteraction(self: *NPCManager) void {
        if (self.player_entity_id == null) return;
        
        const player = self.entity_manager.getEntity(self.player_entity_id.?) orelse return;
        const player_transform_ptr = player.getComponent(entity.ComponentType.Transform) orelse return;
        const player_transform = @as(*entity.Transform, @ptrCast(@alignCast(player_transform_ptr))).*;
        
        // Check interaction key
        if (c.IsKeyPressed(c.KEY_E)) {
            // Find closest NPC within interaction radius
            var closest_npc_id: ?u64 = null;
            var closest_distance: f32 = self.interaction_radius;
            
            for (self.entity_manager.entities.items) |*entity_item| {
                if (entity_item.type_id != entity.EntityType.NPC) continue;
                
                const transform_ptr = entity_item.getComponent(entity.ComponentType.Transform) orelse continue;
                const transform = @as(*entity.Transform, @ptrCast(@alignCast(transform_ptr))).*;
                
                const dx = transform.x - player_transform.x;
                const dy = transform.y - player_transform.y;
                const distance = @sqrt(dx * dx + dy * dy);
                
                if (distance < closest_distance) {
                    closest_distance = distance;
                    closest_npc_id = entity_item.id;
                }
            }
            
            // Interact with closest NPC
            if (closest_npc_id) |id| {
                _ = self.interact(id);
            }
        }
    }
    
    pub fn update(self: *NPCManager) void {
        self.checkPlayerInteraction();
        
        // Update NPCs
        for (self.entity_manager.entities.items) |*entity_item| {
            if (entity_item.type_id != entity.EntityType.NPC) continue;
            
            // For now, NPCs are static
        }
    }
};
