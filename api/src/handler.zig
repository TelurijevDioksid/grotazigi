const std = @import("std");
const pg = @import("pg");
const httpz = @import("httpz");
const jwt = @import("helpers/jwt.zig");
const UUID = @import("helpers/uuid.zig").UUID;
const JwtPayload = @import("models/user.zig").JwtPayload;
const Room = @import("models/room.zig").Room;
const RoomError = @import("models/errors.zig").RoomError;
const Move = @import("models/websock.zig").Move;
const WsMessage = @import("models/websock.zig").WsMessage;
const WsResponse = @import("models/websock.zig").WsResponse;

const Allocator = std.mem.Allocator;
const json = std.json;
const websocket = httpz.websocket;
const base64url = std.base64.url_safe_no_pad;

pub const RoomManager = struct {
    allocator: Allocator,
    rooms: std.StringHashMap(Room),

    pub fn init(allocator: Allocator) RoomManager {
        return .{
            .allocator = allocator,
            .rooms = std.StringHashMap(Room).init(allocator),
        };
    }

    pub fn deinit(self: *RoomManager) void {
        var it = self.rooms.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.rooms.deinit();
    }

    pub fn createRoom(self: *RoomManager, room_name: []const u8) RoomError![]const u8 {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        var rnd = std.Random.DefaultPrng.init(seed);

        const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var code: [5]u8 = undefined;

        while (true) {
            for (&code) |*char| {
                char.* = charset[rnd.random().intRangeLessThan(usize, 0, charset.len)];
            }

            if (!self.rooms.contains(&code)) {
                break;
            }
        }

        const code_copy = self.allocator.dupe(u8, &code) catch {
            return RoomError.RoomServerError;
        };
        const room = Room{
            .name = room_name,
            .code = code_copy,
        };
        self.rooms.put(code_copy, room) catch {
            return RoomError.RoomServerError;
        };
        return code_copy;
    }

    pub fn joinRoom(self: *RoomManager, client: *WsClient) RoomError!void {
        const room = self.rooms.getPtr(client.room_code) orelse {
            return RoomError.RoomNotFound;
        };

        const name_copy = self.allocator.dupe(u8, client.user_id) catch {
            return RoomError.RoomServerError;
        };

        if (room.client1_conn == null) {
            room.client1_conn = client.conn;
            if (room.client1_name) |old_name| self.allocator.free(old_name);
            room.client1_name = name_copy;
            return;
        }

        if (room.client2_conn == null) {
            if (room.client1_name) |name1| {
                if (std.mem.eql(u8, client.user_id, name1)) {
                    client.conn.close(.{ .code = 4000, .reason = "Already joined" }) catch {
                        return RoomError.RoomServerError;
                    };
                    return RoomError.RoomSamePlayer;
                }
            }

            room.client2_conn = client.conn;
            if (room.client2_name) |old_name| self.allocator.free(old_name);
            room.client2_name = name_copy;
            try self.sendMessage(room.client1_conn.?, .{
                .your_score = 0,
                .opponent_score = 0,
                .opponent_name = room.client2_name,
            });
            try self.sendMessage(room.client2_conn.?, .{
                .your_score = 0,
                .opponent_score = 0,
                .opponent_name = room.client1_name,
            });
            return;
        }

        return RoomError.RoomFull;
    }

    pub fn handleMessage(self: *RoomManager, client: *WsClient, data: []const u8) !void {
        const room = self.rooms.getPtr(client.room_code) orelse {
            try client.conn.close(.{ .code = 4004, .reason = "Room not found" });
            return RoomError.RoomNotFound;
        };

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const parsed = json.parseFromSlice(WsMessage, arena.allocator(), data, .{}) catch {
            return RoomError.RoomUnmarshalError;
        };

        const is_client1 = std.mem.eql(u8, client.user_id, room.client1_name.?);

        if (is_client1) {
            if (room.client1_move != null or room.client2_name == null) return;
            room.client1_move = parsed.value.move;
        }
        else {
            if (room.client2_move != null or room.client1_name == null) return;
            room.client2_move = parsed.value.move;
        }

        if (room.client1_move == null or room.client2_move == null) {
            return;
        }

        const winner = determineWinner(room.client1_move.?, room.client2_move.?);
        var client1_win_game: ?bool = null;
        var client2_win_game: ?bool = null;

        if (winner != null and winner.?) {
            room.client1_score += 1;
            if (room.client1_score == 3) {
                room.winner = 1;
                client1_win_game = true;
                client2_win_game = false;
            }
        }
        if (winner != null and !winner.?) {
            room.client2_score += 1;
            if (room.client2_score == 3) {
                room.winner = 2;
                client1_win_game = false;
                client2_win_game = true;
            }
        }

        try self.sendMessage(room.client1_conn.?, .{
            .your_score = room.client1_score,
            .opponent_score = room.client2_score,
            .game_winner = client1_win_game,
            .opponent_move = room.client2_move,
        });
        try self.sendMessage(room.client2_conn.?, .{
            .your_score = room.client2_score,
            .opponent_score = room.client1_score,
            .game_winner = client2_win_game,
            .opponent_move = room.client1_move,
        });

        room.client1_move = null;
        room.client2_move = null;

        if (room.winner != 0) {
            try self.storeRoomInDb(room, client.app_handler);
            try room.client1_conn.?.close(.{ .code = 2000, .reason = "Game finished" });
            try room.client2_conn.?.close(.{ .code = 2000, .reason = "Game finished" });
            self.roomCleanup(room.code);
        }
    }

    pub fn leaveRoom(self: *RoomManager, client: *WsClient) void {
        const room = self.rooms.getPtr(client.room_code) orelse return;
        const is_client1 = std.mem.eql(u8, client.user_id, room.client1_name.?);
        if (is_client1) {
            room.client1_score = 0;
            room.client2_score = 3;
            self.sendMessage(room.client2_conn.?, .{
                .game_winner = true,
                .your_score = 3,
                .opponent_score = 0,
            }) catch {};
        }
        else {
            room.client1_score = 3;
            room.client2_score = 0;
            self.sendMessage(room.client1_conn.?, .{
                .game_winner = true,
                .your_score = 3,
                .opponent_score = 0,
            }) catch {};
        }

        self.storeRoomInDb(room, client.app_handler) catch return;
        self.roomCleanup(room.code);
    }

    fn storeRoomInDb(self: *RoomManager, room: *Room, app_handler: *Handler) !void {
        if (room.client1_name == null or room.client2_name == null) return;

        var one_id: []const u8 = undefined;
        {
            const conn = try app_handler.pool.acquire();
            defer app_handler.pool.release(conn);
            var one_row = try conn.row("select id from users where name = $1", .{room.client1_name.?}) orelse return;
            defer one_row.deinit() catch {};
            one_id = try self.allocator.dupe(u8, one_row.get([]const u8, 0));
        }

        var two_id: []const u8 = undefined;
        {
            const conn = try app_handler.pool.acquire();
            defer app_handler.pool.release(conn);
            var two_row = try conn.row("select id from users where name = $1", .{room.client2_name.?}) orelse return;
            defer two_row.deinit() catch {};
            two_id = try self.allocator.dupe(u8, two_row.get([]const u8, 0));
        }
        defer self.allocator.free(one_id);
        defer self.allocator.free(two_id);

        const conn = try app_handler.pool.acquire();
        defer app_handler.pool.release(conn);

        const id = UUID.init();
        if (room.client1_score > room.client2_score) {
            const query = try std.fmt.allocPrint(self.allocator,
                "insert into games (id, winner, loser, pointswinner, pointsloser) values ('{s}', '{s}', '{s}', {d}, {d})",
                .{ id, one_id, two_id, room.client1_score, room.client2_score });
            defer self.allocator.free(query);
            _ = try conn.exec(query, .{});
        } else {
            const query = try std.fmt.allocPrint(self.allocator,
                "insert into games (id, winner, loser, pointswinner, pointsloser) values ('{s}', '{s}', '{s}', {d}, {d})",
                .{ id, two_id, one_id, room.client2_score, room.client1_score });
            defer self.allocator.free(query);
            _ = try conn.exec(query, .{});
        }
        std.debug.print("\nSTRED IN DB CHECKPOINT storeRoomInDb\n", .{});
    }

    fn roomCleanup(self: *RoomManager, code: []const u8) void {
        if (self.rooms.fetchRemove(code)) |kv| {
            self.allocator.free(kv.key);
            kv.value.deinit(self.allocator);
        }
    }

    fn sendMessage(self: *RoomManager, conn: *websocket.Conn, res: WsResponse) RoomError!void {
        var buff = std.ArrayList(u8).init(self.allocator);
        defer buff.deinit();
        json.stringify(res, .{}, buff.writer()) catch { return RoomError.RoomServerError; };
        conn.write(buff.items) catch { return RoomError.RoomServerError; };
    }

    fn determineWinner(move1: Move, move2: Move) ?bool {
        if (move1 == move2) return null;
        return switch (move1) {
            .rock => move2 == .scissors,
            .paper => move2 == .rock,
            .scissors => move2 == .paper,
        };
    }
};

pub const Handler = struct {
    pool: *pg.Pool,
    room_manager: RoomManager,
    jwt_secret: []const u8 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",

    pub const WebsocketHandler = WsClient;

    pub fn init(pool: *pg.Pool, allocator: Allocator) Handler {
        return .{
            .pool = pool,
            .room_manager = RoomManager.init(allocator),
        };
    }

    pub fn deinit(self: *Handler) void {
        self.pool.deinit();
        self.room_manager.deinit();
    }

    pub fn dispatch(self: *Handler, action: httpz.Action(*Handler), req: *httpz.Request, res: *httpz.Response) !void {
        if (std.mem.eql(u8, req.url.path, "/ws")
            or std.mem.eql(u8, req.url.path, "/api/login")
            or std.mem.eql(u8, req.url.path, "/api/register")) {
            try action(self, req, res);
            return;
        }

        const token = req.cookies().get("auth") orelse {
            res.status = 401;
            return;
        };

        const key = try res.arena.alloc(u8, try base64url.Decoder.calcSizeForSlice(self.jwt_secret));
        try base64url.Decoder.decode(key, self.jwt_secret);

        const claims_p = jwt.validate(JwtPayload, res.arena, .HS256, token, .{ .key = key }) catch {
            res.status = 401;
            return;
        };
        const claims = claims_p.value;

        if (claims.admin == false and (
            std.mem.eql(u8, req.url.path[0..9], "/api/user")
            or (
                std.mem.eql(u8, req.url.path[0..9], "/api/game")
                and req.method != httpz.Method.GET
            )
        )) {
            res.status = 401;
            return;
        }

        if (claims.exp < std.time.timestamp()) {
            res.status = 401;
            return;
        }

        try action(self, req, res);
    }
};

pub const WsClient = struct {
    user_id: []const u8,
    room_code: []const u8,
    conn: *websocket.Conn,
    app_handler: *Handler,

    pub const WsContext = struct {
        user_id: []const u8,
        room_code: []const u8,
        app_handler: *Handler,
    };

    pub fn init(conn: *websocket.Conn, ctx: *const WsContext) !WsClient {
        return .{
            .conn = conn,
            .user_id = ctx.user_id,
            .room_code = ctx.room_code,
            .app_handler = ctx.app_handler,
        };
    }

    pub fn deinit(self: *WsClient) void {
        self.app_handler.room_manager.allocator.free(self.room_code);
        self.app_handler.room_manager.allocator.free(self.user_id);
    }

    pub fn afterInit(self: *WsClient) !void {
        self.app_handler.room_manager.joinRoom(self) catch |err| switch (err) {
            error.RoomNotFound => {
                try self.conn.close(.{
                    .code = 4004,
                    .reason = "Room not found",
                });
            },
            error.RoomFull => {
                try self.conn.close(.{
                    .code = 4000,
                    .reason = "Room is full",
                });
            },
            else => {
                try self.conn.close(.{
                    .code = 5000,
                    .reason = "Server Error",
                });
            },
        };
    }

    pub fn clientMessage(self: *WsClient, data: []const u8) !void {
        self.app_handler.room_manager.handleMessage(self, data) catch |err| switch (err) {
            error.RoomServerError => {
                try self.conn.close(.{
                    .code = 5000,
                    .reason = "Server Error",
                });
            },
            error.RoomNotFound => {
                try self.conn.close(.{
                    .code = 4004,
                    .reason = "Room not found",
                });
            },
            else => {
                try self.conn.close(.{
                    .code = 5000,
                    .reason = "Server Error",
                });
            },
        };
    }

    pub fn close(self: *WsClient) void {
        self.app_handler.room_manager.leaveRoom(self);
        self.deinit();
    }
};

