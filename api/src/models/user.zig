pub const User = struct {
    id: []const u8,
    name: []const u8,
    password: []const u8,
    salt: []const u8,
    admin: bool,
};

pub const RegisterDto = struct {
    name: []const u8,
    password: []const u8,
};

pub const LoginDto = struct {
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

pub const UserDto = struct {
    id: []const u8,
    name: []const u8,
    password: []const u8,
    salt: []const u8,
};

pub const ProfileDto = struct {
    name: []const u8,
};

pub const CreateUserDto = struct {
    name: []const u8,
    password: []const u8,
    salt: []const u8,
};

pub const UpdateUserDto = struct {
    name: ?[]const u8,
    password: ?[]const u8,
    salt: ?[]const u8,
};

