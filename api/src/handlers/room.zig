const std = @import("std");
const httpz = @import("httpz");
const handler = @import("../handler.zig");
const RoomDto = @import("../models/room.zig").RoomDto;
const CreateRoomDto = @import("../models/room.zig").CreateRoomDto;

const Handler = handler.Handler;

pub fn getRooms(app_handler: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    var rooms = std.ArrayList(RoomDto).init(res.arena);
    var it = app_handler.room_manager.rooms.valueIterator();

    while (it.next()) |room| {
        var count: u8 = 0;
        if (room.client1_conn != null) count += 1;
        if (room.client2_conn != null) count += 1;
        try rooms.append(.{
            .name = room.name,
            .code = room.code,
            .players = count,
        });
    }

    res.status = 200;
    try res.json(rooms.items, .{});
}

pub fn createRoom(app_handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    if (try req.json(CreateRoomDto)) |room| {
        if (room.name.len == 0 or room.name.len > 32) {
            res.status = 400;
            res.body = "Invalid room name";
            return;
        }

        const code = app_handler.room_manager.createRoom(room.name) catch {
            res.status = 500;
            res.body = "Could not create room";
            return;
        };

        res.status = 200;
        try res.json(RoomDto{
            .code = code,
            .name = room.name,
            .players = 0,
        }, .{});
        return;
    }
    res.status = 400;
    res.body = "Invalid request body";
}

