pub const User = struct {
    id: []const u8,
    name: []const u8,
    email: []const u8,
};

pub const Article = struct {
    id: ?[]const u8,
    title: []const u8,
    author: []const u8,
    image: []const u8,
    summary: []const u8,
};

pub const Root = struct {
    title: []u8,
    author: []u8,
    image: []u8,
    summary: []u8,
};

pub const CredentialsReq = struct {
    name: []const u8,
    email: []const u8,
    password: []const u8,
};
// pub const GetId = struct { id: []u8 };
