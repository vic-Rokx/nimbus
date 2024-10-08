const std = @import("std");
const helpers = @import("../../helpers/index.zig");
const Context = @import("../../context/index.zig");
const User = @import("../models.zig").User;
const cache = @import("../data/index.zig");

pub fn createUser(ctx: *Context) anyerror!void {
    var user = try ctx.bind(User);
    var uuid_buf: [36]u8 = undefined;
    helpers.newV4().to_string(&uuid_buf);
    user.id = try helpers.convertStringToSlice(&uuid_buf, std.heap.c_allocator);
    try cache.user_db.put(user.id.?, user);
    _ = try ctx.STRING(user.id.?);
}

pub fn updateUser(ctx: *Context) anyerror!void {
    var user = try ctx.bind(User);
    user.id = try helpers.convertStringToSlice(user.id.?, std.heap.c_allocator);
    try cache.user_db.put(user.id.?, user);
    const cached_user = try cache.user_db.get(user.id.?);
    _ = try ctx.JSON(User, cached_user);
}

pub fn getUserById(ctx: *Context) anyerror!void {
    const id = try ctx.param("id");
    const user = try cache.user_db.get(id);
    _ = try ctx.JSON(User, user);
}
