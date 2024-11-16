const std = @import("std");
const helpers = @import("../../helpers/index.zig");
const Context = @import("../../context/index.zig");
const User = @import("../models.zig").User;
const nimbus_cache = @import("../init/index.zig");
const cache = @import("../data/index.zig");
const NimbusClient = @import("../../client/index.zig");
const Cookie = @import("../../core/Cookie.zig");

pub fn pingNimbus(ctx: *Context) !void {
    const resp = try nimbus_cache.cache_client_one.ping();
    _ = try ctx.STRING(resp);
}

fn readAuthCookie(ctx: *Context) ?Cookie {
    const cookie = ctx.getCookie("Authorization");
    return cookie;
}

pub fn setServerCookie(ctx: *Context) !void {
    var hash_buf: [36]u8 = undefined;
    helpers.newV4().to_string(&hash_buf);
    const expires = std.time.timestamp();
    const cookie = Cookie.init("X-LB-Session=8082", hash_buf, expires);
    try ctx.putCookie(cookie);
    _ = try ctx.STRING("cookie written");
}

pub fn ping(ctx: *Context) !void {
    const auth_cookie = readAuthCookie(ctx);
    if (auth_cookie == null) {
        var uuid_buf: [36]u8 = undefined;
        helpers.newV4().to_string(&uuid_buf);
        const hash = try helpers.convertStringToSlice(&uuid_buf, std.heap.c_allocator);

        const expires = std.time.timestamp();
        const cookie = Cookie.init("Authorization", hash, expires);
        try ctx.putCookie(cookie);
    }
    _ = try ctx.STRING("PONG");
}

pub fn set(ctx: *Context) !void {
    const resp = try nimbus_cache.cache_client_one.set("name", "Vic");
    _ = try ctx.STRING(resp);
}

pub fn dllNimbus(ctx: *Context) !void {
    var str_arr = [_][]const u8{ "one", "two", "three" };
    const resp = try nimbus_cache.cache_client_one.lpushmany(3, "mylist", &str_arr);
    _ = try ctx.STRING(resp);
}

pub fn dllRangeNimbus(ctx: *Context) !void {
    try nimbus_cache.cache_client_one.lrange("mylist", "0", "-1");
    _ = try ctx.STRING("Success");
}

pub fn dllNimbus_two(ctx: *Context) !void {
    var str_arr = [_][]const u8{ "four", "five", "six", "seven" };
    const resp = try nimbus_cache.cache_client_two.lpushmany(4, "mylist", &str_arr);
    _ = try ctx.STRING(resp);
}

pub fn updateUser(ctx: *Context) anyerror!void {
    const id = ctx.param("id") catch {
        try ctx.ERROR(401, "Param Error: Could not find param");
        return error.InternalServerError;
    };
    var user = cache.user_db.get(id) catch |err| {
        std.debug.print("\n{}", .{err});
        try ctx.ERROR(401, "Database Error: Value not found");
        return error.InternalServerError;
    };

    var new_user = ctx.bind(User) catch {
        try ctx.ERROR(401, "Bind error: Could not bind");
        return error.InternalServerError;
    };

    _ = ctx.JSON(User, new_user) catch {
        try ctx.ERROR(401, "Update Error: Could not update");
        return error.InternalServerError;
    };
    new_user.id = try helpers.convertStringToSlice(user.id, ctx.arena);
    user = new_user;
    try cache.user_db.put(user.id, user);
    const patched_user = try cache.user_db.get(user.id);
    _ = ctx.JSON(User, patched_user) catch {
        try ctx.ERROR(401, "Update Error: Could not update");
        return error.InternalServerError;
    };
}

pub fn getUserById(ctx: *Context) anyerror!void {
    const id = ctx.param("id") catch {
        try ctx.ERROR(401, "Param Error: Could not find param");
        return error.InternalServerError;
    };
    const user = cache.user_db.get(id) catch |err| {
        std.debug.print("\n{}", .{err});
        try ctx.ERROR(401, "Database Error: Value not found");
        return error.InternalServerError;
    };
    _ = ctx.JSON(User, user) catch {
        try ctx.ERROR(401, "Reponse Error: Could not send JSON response");
        return error.InternalServerError;
    };
}
