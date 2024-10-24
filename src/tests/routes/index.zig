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

fn readCookie(ctx: *Context) ?Cookie {
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
    const auth_cookie = readCookie(ctx);
    if (auth_cookie == null) {
        var uuid_buf: [36]u8 = undefined;
        helpers.newV4().to_string(&uuid_buf);
        const hash = try helpers.convertStringToSlice(&uuid_buf, std.heap.c_allocator);

        const expires = std.time.timestamp();
        const cookie = Cookie.init("Authorization", hash, expires);
        try ctx.setCookie(cookie);
    }
    _ = try ctx.STRING("PONG");
}

pub fn dllNimbus(ctx: *Context) !void {
    var str_arr = [_][]const u8{ "one", "two", "three" };
    const resp = try nimbus_cache.cache_client_one.lpush(3, "mylist", &str_arr);
    _ = try ctx.STRING(resp);
}

pub fn dllNimbus_two(ctx: *Context) !void {
    var str_arr = [_][]const u8{ "four", "five", "six", "seven" };
    const resp = try nimbus_cache.cache_client_two.lpush(4, "mylist", &str_arr);
    _ = try ctx.STRING(resp);
}

pub fn createUser(ctx: *Context) !void {
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
