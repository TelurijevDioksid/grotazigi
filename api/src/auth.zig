const std = @import("std");
const httpz = @import("httpz");
const hlr = @import("handler.zig");
const UUID = @import("uuid.zig").UUID;
const jwt = @import("jwt.zig");
const crypto = std.crypto;
const base64url = std.base64.url_safe_no_pad;

const Handler = hlr.Handler;

pub const User = struct {
    id: []const u8,
    name: []const u8,
    password: []const u8,
    salt: []const u8,
    admin: bool,
};
const RegisterDto = struct {
    name: []const u8,
    password: []const u8,
};

const LoginDto = struct {
    name: []const u8,
    password: []const u8,
};

pub const JwtPayload = struct {
    iss: []const u8,
    exp: i64,
    sub: []const u8,
    aud: []const u8,
    admin: bool,
};

pub fn login(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    if (try req.json(LoginDto)) |user| {
        const conn = try handler.pool.acquire();
        defer handler.pool.release(conn);

        var row = try conn.rowOpts("select * from users where name = $1", .{ user.name }, .{ .column_names = true }) orelse {
            res.status = 401;
            res.body = "Username or password incorrect";
            return;
        };
        defer row.deinit() catch {};
        const user_row = try row.to(User, .{});

        var salt: [16]u8 = undefined;
        std.mem.copyForwards(u8, &salt, user_row.salt);

        const hashed_pwd = crypto.pwhash.bcrypt.bcrypt(user.password, salt, .{ .rounds_log = 10, .silently_truncate_password = false });
        if (!std.mem.eql(u8, &hashed_pwd, user_row.password)) {
            res.status = 401;
            res.body = "Username or password incorrect";
            return;
        }

        const key = try res.arena.alloc(u8, try base64url.Decoder.calcSizeForSlice(handler.jwt_secret));
        try base64url.Decoder.decode(key, handler.jwt_secret);
        const payload = JwtPayload{
            .iss = "http://localhost:8080",
            .exp = std.time.timestamp() + 86400,
            .sub = user_row.name,
            .aud = "http://localhost:8080",
            .admin = user_row.admin,
        };
        const token = try jwt.encode(res.arena, .HS256, payload, .{ .key = key });

        res.status = 200;
        try res.setCookie("auth", token, .{
            .http_only = true,
            .secure = false,
            .same_site = .lax,
            .domain = "localhost",
            .path = "/api",
        });
    } else {
        res.status = 401;
        res.body = "Username or password incorrect";
    }
}

pub fn register(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    if (try req.json(RegisterDto)) |user| {
        const conn = try handler.pool.acquire();
        defer handler.pool.release(conn);

        const existing_user_row = (try conn.row("select * from users where name = $1", .{user.name})) orelse null;
        if (existing_user_row != null) {
            res.status = 400;
            res.body = "Username is taken, please choose another one";
            return;
        }

        var salt_bytes: [16]u8 = undefined;
        crypto.random.bytes(&salt_bytes);
        const hash_pwd = crypto.pwhash.bcrypt.bcrypt(user.password, salt_bytes, .{ .rounds_log = 10, .silently_truncate_password = false });

        const id = try std.fmt.allocPrint(res.arena, "{s}", .{UUID.init()});
        const result = try conn.exec(
            "insert into users (id, name, password, salt, admin) values ($1, $2, $3, $4, $5)",
            .{ id, user.name, hash_pwd, salt_bytes, false });
        if (result.? == 1) {
            res.status = 201;
            return;
        }
    }
    res.status = 500;
}

pub fn logout(_: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    res.status = 200;
    try res.setCookie("auth", "", .{
        .http_only = true,
        .secure = false,
        .same_site = .lax,
        .domain = "localhost",
        .max_age = 0,
        .path = "/api",
    });
}

