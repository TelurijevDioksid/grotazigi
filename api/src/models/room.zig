const std = @import("std");
const websocket = @import("httpz").websocket;
const Move = @import("websock.zig").Move;

const Allocator = std.mem.Allocator;

pub const Room = struct {
    name: []const u8,
    code: []const u8,
    winner: u8 = 0,
    client1_conn: ?*websocket.Conn = null,
    client2_conn: ?*websocket.Conn = null,
    client1_name: ?[]const u8 = null,
    client2_name: ?[]const u8 = null,

    client1_move: ?Move = null,
    client2_move: ?Move = null,
    client1_score: u8 = 0,
    client2_score: u8 = 0,

    pub fn deinit(self: Room, allocator: Allocator) void {
        if (self.client1_name) |name_slice| allocator.free(name_slice);
        if (self.client2_name) |name_slice| allocator.free(name_slice);
    }
};

pub const RoomDto = struct {
    name: []const u8,
    code: []const u8,
    players: u8,
};

pub const CreateRoomDto = struct {
    name: []const u8,
};

