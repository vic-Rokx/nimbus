const std = @import("std");
const Context = @import("../../context/index.zig");
const helpers = @import("../../helpers/index.zig");
const Cookie = @import("../../core/Cookie.zig");
const HandlerFunc = @import("../../nimbus/server.zig").HandlerFunc;
const CredentialsReq = @import("../models.zig").CredentialsReq;
const Auth = @import("../../auth/index.zig");
const User = @import("../models.zig").User;
const cache = @import("../data/index.zig");
const session_utils = @import("../../session_utils/index.zig");

fn readCookie(ctx: *Context) ![]const u8 {
    const cookie = try ctx.getCookie("Authorization");
    return cookie;
}

pub fn validate(next: HandlerFunc, ctx: *Context) !HandlerFunc {
    const cookie = try readCookie(ctx);
    std.debug.print("\nAuth Cookie token: {s}", .{cookie});
    return next;
}

pub fn verifyAuth(next: HandlerFunc, ctx: *Context) !HandlerFunc {
    const creds = ctx.bind(CredentialsReq) catch {
        try ctx.ERROR(401, "Middleware error: Could not bind data");
        return error.InternalServerError;
    };
    var arena = std.heap.page_allocator;
    // Compare and generate password are purposely slow
    const hash = try Auth.generatePassword(creds.password[0..], &arena);
    const verified = Auth.comparePassword(creds.password[0..], hash, &arena) catch {
        try ctx.ERROR(401, "Password error: Compare failed");
        return error.InternalServerError;
    };
    if (verified == Auth.AuthEnum.Success) {
        return next;
    } else {
        try ctx.ERROR(401, "Internal Server Error: retry");
        return error.InternalServerError;
    }
}
