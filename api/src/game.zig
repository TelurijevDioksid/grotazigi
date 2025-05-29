const std = @import("std");
const httpz = @import("httpz");
const hlr = @import("handler.zig");
const UUID = @import("uuid.zig").UUID;

const Handler = hlr.Handler;

const GameDto = struct {
    winner: []const u8,
    loser: []const u8,
    pointswinner: i32,
    pointsloser: i32,
};

const CreateGameDto = struct {
    winner: []const u8,
    loser: []const u8,
    pointswinner: i32,
    pointsloser: i32,
};

const UpdateGameDto = struct {
    winner: ?[]const u8,
    loser: ?[]const u8,
    pointswinner: ?i32,
    pointsloser: ?i32,
};

pub fn getGames(handler: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    const conn = try handler.pool.acquire();
    defer handler.pool.release(conn);

    var result = try conn.queryOpts(
        "select wu.name as winner, lu.name as loser, g.pointswinner, g.pointsloser from games g " ++
        "join users wu on g.winner = wu.id join users lu on g.loser = lu.id",
        .{}, .{ .column_names = true });
    defer result.deinit();

    var mapper = result.mapper(GameDto, .{});

    var games = std.ArrayList(GameDto).init(res.arena);

    while (try mapper.next()) |game| {
        try games.append(game);
    }

    try res.json(games.items, .{});
}

pub fn getGame(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const id = req.param("id").?;

    _ = UUID.parse(id) catch {
        res.status = 400;
        try res.json(.{
            .message = "Invalid UUID",
        }, .{});
        return;
    };

    const conn = try handler.pool.acquire();
    defer handler.pool.release(conn);

    var row = try conn.rowOpts(
        "select wu.name as winner, lu.name as loser, g.pointswinner, g.pointsloser from games g " ++
        "join users wu on g.winner = wu.id join users lu on g.loser = lu.id where g.id = $1",
        .{id}, .{ .column_names = true })
    orelse {
        res.status = 404;
        try res.json(.{
            .message = "Game not found",
        }, .{});
        return;
    };
    defer row.deinit() catch {};

    const game = try row.to(GameDto, .{});
    try res.json(game, .{});
}

pub fn createGame(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    if (try req.json(CreateGameDto)) |game| {
        const conn = try handler.pool.acquire();
        defer handler.pool.release(conn);

        if (game.pointsloser < 0 or game.pointsloser > 3 or game.pointswinner < 0 or game.pointswinner > 3) {
            res.status = 400;
            try res.json(.{
                .message = "Invalid points, value must be between 0 and 3",
            }, .{});
            return;
        }

        {
            var winner = try conn.row("select * from games where id = $1", .{game.winner}) orelse {
                res.status = 400;
                const msg = try std.fmt.allocPrint(res.arena, "User with id {s} not found", .{game.winner});
                try res.json(.{
                    .message = msg,
                }, .{});
                return;
            };
            defer winner.deinit() catch {};
        }

        {
            var loser = try conn.row("select * from users where id = $1", .{game.loser}) orelse {
                res.status = 400;
                const msg = try std.fmt.allocPrint(res.arena, "User with id {s} not found", .{game.loser});
                try res.json(.{
                    .message = msg,
                }, .{});
                return;
            };
            loser.deinit() catch {};
        }

        const id = UUID.init();

        const result = try conn.exec(
            "insert into games (id, winner, loser, pointswinner, pointsloser ) values ($1, $2, $3, $4, $5, $6)",
            .{ id, game.winner, game.loser, game.pointswinner, game.pointsloser },);
        if (result.? == 1) {
            res.status = 201;
            return;
        }
    }
    res.status = 400;
    try res.json(.{
        .message = "Invalid request body",
    }, .{});
}

pub fn updateGame(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const id = req.param("id").?;

    _ = UUID.parse(id) catch {
        res.status = 400;
        try res.json(.{
            .message = "Invalid UUID",
        }, .{});
        return;
    };

    if (try req.json(UpdateGameDto)) |game| {
        const conn = try handler.pool.acquire();
        defer handler.pool.release(conn);

        var changed = false;
        var buff = std.ArrayList(u8).init(res.arena);

        const writer = buff.writer();
        try writer.print("update games set ", .{});
        if (game.winner) |user| {
            {
                var exists = try conn.row("select * from users where id = $1", .{user}) orelse {
                    res.status = 400;
                    const msg = try std.fmt.allocPrint(res.arena, "User with id {s} not found", .{user});
                    try res.json(.{
                        .message = msg,
                    }, .{});
                    return;
                };
                defer exists.deinit() catch {};
            }
            changed = true;
            try writer.print("winner = {s}, ", .{user});
        }
        if (game.loser) |user| {
            {
                var exists = try conn.row("select * from users where id = $1", .{user}) orelse {
                    res.status = 400;
                    const msg = try std.fmt.allocPrint(res.arena, "User with id {s} not found", .{user});
                    try res.json(.{
                        .message = msg,
                    }, .{});
                    return;
                };
                defer exists.deinit() catch {};
            }
            changed = true;
            try writer.print("loser = {s}, ", .{user});
        }
        if (game.pointswinner) |points| {
            changed = true;
            try writer.print("pointswinner = {d}, ", .{points});
        }
        if (game.pointsloser) |points| {
            changed = true;
            try writer.print("pointsloser = {d}, ", .{points});
        }
        if (!changed) {
            res.status = 400;
            try res.json(.{
                .message = "Invalid request body",
            }, .{});
            return;
        }

        buff.items.len -= 2;
        try writer.print("where id = {s}", .{id});

        const result = try conn.exec(buff.items, .{});
        if (result.? == 1) {
            res.status = 204;
            return;
        }
    }

    res.status = 400;
    try res.json(.{
        .message = "Invalid request body",
    }, .{});
}

pub fn deleteGame(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const id = req.param("id").?;

    _ = UUID.parse(id) catch {
        res.status = 400;
        try res.json(.{
            .message = "Invalid UUID",
        }, .{});
        return;
    };

    const conn = try handler.pool.acquire();
    defer handler.pool.release(conn);

    const result = try conn.exec("delete from games where id = $1", .{id});
    if (result == null or result.? == 0) {
        res.status = 404;
        try res.json(.{
            .message = "Game not found",
        }, .{});
        return;
    }

    res.status = 204;
}

