const std = @import("std");
const httpz = @import("httpz");
const hlr = @import("handler.zig");
const UUID = @import("uuid.zig").UUID;
const jwt = @import("jwt.zig");
const JwtPayload = @import("auth.zig").JwtPayload;

const Handler = hlr.Handler;

const UserDto = struct {
    id: []const u8,
    name: []const u8,
    password: []const u8,
    salt: []const u8,
};

const ProfileDto = struct {
    name: []const u8,
};

const CreateUserDto = struct {
    name: []const u8,
    password: []const u8,
    salt: []const u8,
};

const UpdateUserDto = struct {
    name: ?[]const u8,
    password: ?[]const u8,
    salt: ?[]const u8,
};

pub fn getProfile(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const token = req.cookies().get("auth").?;
    const claims = try jwt.extractClaims(JwtPayload, res.arena, token);

    const conn = try handler.pool.acquire();
    defer handler.pool.release(conn);

    var row = try conn.rowOpts(
        "select name from users where name = $1", .{ claims.value.sub }, .{ .column_names = true }
    ) orelse {
        res.status = 404;
        try res.json(.{
            .message = "User not found",
        }, .{});
        return;
    };
    defer row.deinit() catch {};

    const user = try row.to(ProfileDto, .{});

    try res.json(user, .{});
}

pub fn getUsers(handler: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    const conn = try handler.pool.acquire();
    defer handler.pool.release(conn);

    var result = try conn.queryOpts("select * from users", .{}, .{ .column_names = true });
    defer result.deinit();

    var mapper = result.mapper(UserDto, .{});

    var users = std.ArrayList(UserDto).init(res.arena);
    defer users.deinit();

    while (try mapper.next()) |user| {
        try users.append(user);
    }

    try res.json(users.items, .{});
}

pub fn getUser(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
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

    var row = try conn.rowOpts("select * from users where id = $1", .{id}, .{ .column_names = true }) orelse null;
    defer row.?.deinit() catch {};

    const user = row.?.to(UserDto, .{}) catch {
        res.status = 404;
        try res.json(.{
            .message = "User not found",
        }, .{});
        return;
    };

    try res.json(user, .{});
}

pub fn createUser(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    if (try req.json(CreateUserDto)) |user| {
        const conn = try handler.pool.acquire();
        defer handler.pool.release(conn);

        const id = UUID.init();

        const result = try conn.exec(
            "insert into users (id, name, password, salt, admin) values ($1, $2, $3, $4, $5)",
            .{ id, user.name, user.password, user.salt, false });
        if (result != null and result.? == 1) {
            res.status = 201;
            return;
        }
    }
    res.status = 400;
    try res.json(.{
        .message = "Invalid request body",
    }, .{});
}

pub fn updateUser(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const id = req.param("id").?;

    _ = UUID.parse(id) catch {
        res.status = 400;
        try res.json(.{
            .message = "Invalid UUID",
        }, .{});
        return;
    };

    if (try req.json(UpdateUserDto)) |user| {
        const conn = try handler.pool.acquire();
        defer handler.pool.release(conn);

        var changed = false;
        var buff = std.ArrayList(u8).init(res.arena);
        defer buff.deinit();

        const writer = buff.writer();
        try writer.print("update users set ", .{});
        if (user.name) |name| {
            changed = true;
            try writer.print("name = {s}, ", .{name});
        }
        if (user.password) |password| {
            changed = true;
            try writer.print("password = {s}, ", .{password});
        }
        if (user.salt) |salt| {
            changed = true;
            try writer.print("salt = {s}, ", .{salt});
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

pub fn deleteUser(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
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

    const result = try conn.exec("delete from users where id = $1", .{id});
    if (result == null or result.? == 0) {
        res.status = 404;
        try res.json(.{
            .message = "User not found",
        }, .{});
        return;
    }

    res.status = 204;
}

