pub const GameDto = struct {
    winner: []const u8,
    loser: []const u8,
    pointswinner: i32,
    pointsloser: i32,
};

pub const CreateGameDto = struct {
    winner: []const u8,
    loser: []const u8,
    pointswinner: i32,
    pointsloser: i32,
};

pub const UpdateGameDto = struct {
    winner: ?[]const u8,
    loser: ?[]const u8,
    pointswinner: ?i32,
    pointsloser: ?i32,
};

