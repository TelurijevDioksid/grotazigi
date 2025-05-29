const std = @import("std");
const pg = @import("pg");
const httpz = @import("httpz");
const handler = @import("handler.zig");
const jwt = @import("helpers/jwt.zig");
const UUID = @import("helpers/uuid.zig").UUID;
const user = @import("handlers/user.zig");
const auth = @import("handlers/auth.zig");
const room = @import("handlers/room.zig");
const game = @import("handlers/game.zig");

const Allocator = std.mem.Allocator;
const Handler = handler.Handler;
const WsClient = handler.WsClient;

fn shutdown(_: c_int) callconv(.C) void {
    if (server_instance) |s| {
        server_instance = null;
        s.stop();
        std.debug.print("\n\nServer shutting down...\n\n", .{});
    }
}

var server_instance: ?*httpz.Server(*Handler) = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.print("\n\nMemory leaks: {}\n\n", .{gpa.deinit() != .ok});

    std.posix.sigaction(std.posix.SIG.INT, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    }, null);
    std.posix.sigaction(std.posix.SIG.TERM, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    }, null);

    const pool = try pg.Pool.init(allocator, .{ .connect = .{
        .port = 5432,
        .host = "localhost",
    }, .auth = .{
        .database = "db",
        .username = "postgres",
        .password = "postgres",
    } });

    var app = Handler.init(pool, allocator);
    defer app.deinit();

    var server = try httpz.Server(*Handler).init(allocator, .{ .port = 8080 }, &app);
    defer server.deinit();

    const cors = try server.middleware(httpz.middleware.Cors, .{
        .origin = "http://localhost:5173",
    });

    var router = try server.router(.{
        .middlewares = &.{ cors },
    });

    router.get("/api/user", user.getUsers, .{});
    router.get("/api/user/:id", user.getUser, .{});
    router.post("/api/user", user.createUser, .{});
    router.put("/api/user/:id", user.updateUser, .{});
    router.delete("/api/user/:id", user.deleteUser, .{});
    router.get("/api/profile", user.getProfile, .{});
    router.post("/api/register", auth.register, .{});
    router.post("/api/login", auth.login, .{});
    router.get("/api/logout", auth.logout, .{});
    router.get("api/rooms", room.getRooms, .{});
    router.post("api/rooms", room.createRoom, .{});
    router.get("/api/game", game.getGames, .{});
    router.get("/api/game/me", game.getPersonalGames, .{});
    router.get("/api/game/:id", game.getGame, .{});
    router.post("/api/game", game.createGame, .{});
    router.put("/api/game/:id", game.updateGame, .{});
    router.delete("/api/game/:id", game.deleteGame, .{});
    router.get("/ws", ws, .{});

    std.debug.print("Listening on port 8080\n", .{});
    server_instance = &server;
    try server.listen();
}

fn ws(app: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const query = try req.query();
    const user_id = query.get("user") orelse {
        res.status = 400;
        res.body = "Missing user id";
        return;
    };
    const room_code = query.get("room") orelse {
        res.status = 400;
        res.body = "Missing room code";
        return;
    };

    const user_id_copy = try app.room_manager.allocator.dupe(u8, user_id);
    const room_code_copy = try app.room_manager.allocator.dupe(u8, room_code);
    const ctx = WsClient.WsContext{
        .user_id = user_id_copy,
        .room_code = room_code_copy,
        .app_handler = app,
    };

    if (try httpz.upgradeWebsocket(WsClient, req, res, &ctx) == false) {
        res.status = 400;
        res.body = "WebSocket upgrade failed";
    }
}

