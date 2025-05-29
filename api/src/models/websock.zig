pub const Move = enum(u8) {
    rock = 1,
    paper = 2,
    scissors = 3,
};

pub const WsMessage = struct {
    move: Move,
};

pub const WsResponse = struct {
    opponent_name: ?[]const u8 = null,
    your_score: ?u8 = null,
    opponent_score: ?u8 = null,
    game_winner: ?bool = null,
    opponent_move: ?Move = null,
};

