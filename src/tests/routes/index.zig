const std = @import("std");
const helpers = @import("../helpers/index.zig");
const Context = @import("../../tempest/context.zig");
const User = @import("../models.zig").User;
const cache = @import("../data/index.zig");

pub fn createUser(ctx: *Context) anyerror!void {
    const user = try ctx.bind(User);
    try cache.user_db.put("id10", user);
    const result = try cache.user_db.get("id10");

    std.debug.print("\nname: {s}\n", .{result.name});
}

pub fn createUserTest(allocator: std.mem.Allocator) anyerror!void {
    const user = User{
        .id = null,
        .name = try helpers.convertStringToSlice("Alice", allocator),
        .age = 30,
        .height = 170,
        .weight = 60,
        .favoriteLanguage = try helpers.convertStringToSlice("Zig", allocator),
    };

    try cache.user_db.put("id1", user);
}

pub fn getUser(ctx: *Context) anyerror!void {
    const name = try ctx.param("name");
    std.debug.print("\n name: {s}\n", .{name});

    // Handle GET request
}

// pub fn getArticle(ctx: Context(Article)) anyerror!void {
//     const title = try ctx.param([]u8, "title");
//     std.debug.print("\n title: {s}\n", .{title});
// }
