const std = @import("std");
const Context = @import("../../context/index.zig");
const helpers = @import("../../helpers/index.zig");
const Cookie = @import("../../core/Cookie.zig");
const HandlerFunc = @import("../../tempest/server.zig").HandlerFunc;
const CredentialsReq = @import("../models.zig").CredentialsReq;
const Auth = @import("../../auth/index.zig");
const User = @import("../models.zig").User;

fn readCookie(ctx: *Context) ![]const u8 {
    const cookie = try ctx.getCookie("Authorization");
    return cookie;
}

pub fn validate(next: HandlerFunc, ctx: *Context) HandlerFunc {
    // _ = try ctx.bind(User);
    // user.favoriteLanguage = "Golang is better";
    // ctx.setValues("user", user);
    std.debug.print("\nroute {s}", .{ctx.route});
    return next;
}

fn verifyAuth(next: HandlerFunc, ctx: *Context) HandlerFunc {
    ctx.user_id += 300;
    return next;
}

pub fn signup(ctx: *Context) !void {
    const credentials = try ctx.bind(CredentialsReq);
    var hash = try Auth.generatePassword(credentials.password);
    var uuid_buf: [36]u8 = undefined;
    helpers.newV4().to_string(&uuid_buf);
    hash = try helpers.convertStringToSlice(&uuid_buf, std.heap.c_allocator);

    const expires = std.time.timestamp();
    const cookie = Cookie.init("Authorization", hash, expires);
    try ctx.setCookie(cookie);
    _ = try ctx.STRING("cookie written");
}
