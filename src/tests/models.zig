pub const User = struct {
    id: ?[]const u8,
    name: []const u8,
    age: usize,
    height: usize,
    weight: usize,
    favoriteLanguage: []const u8,
};

pub const Article = struct {
    id: ?[]u8,
    title: []u8,
    author: []u8,
    image: []u8,
    summary: []u8,
};

pub const Root = struct {
    title: []u8,
    author: []u8,
    image: []u8,
    summary: []u8,
};

pub const CredentialsReq = struct {
    email: []u8,
    password: []u8,
};
// pub const GetId = struct { id: []u8 };
