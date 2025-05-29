pub const RoomError = error{
    RoomExists,
    RoomNotFound,
    RoomFull,
    RoomUnmarshalError,
    RoomSamePlayer,
    RoomServerError,
    RoomPasswordError,
};

