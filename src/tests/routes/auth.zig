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

pub fn createCacheSession(next: HandlerFunc, _: *Context) !HandlerFunc {
    var cache_hash: [36]u8 = undefined;
    helpers.newV4().to_string(&cache_hash);
    const expires = std.time.timestamp();
    _ = Cookie.init("cache-session", &cache_hash, expires);
    // try ctx.putCookie(cookie);
    return next;
}

pub fn signup(ctx: *Context) !void {
    // Bind credentials
    const credentials = try ctx.bind(CredentialsReq);

    // Generate hash
    const hash = try Auth.generatePassword(credentials.password, &ctx.arena);

    // generate new uuid
    var uuid_buf: [36]u8 = undefined;
    helpers.newV4().to_string(&uuid_buf);

    // generate session token
    var session_token: [36]u8 = undefined;
    session_utils.generateSessionToken(session_token[0..]);

    // store password in hash_db
    try cache.user_hash_db.put(uuid_buf[0..], hash);

    // generate session cookie
    const expires = std.time.timestamp();
    const cookie = Cookie.init("Authorization", session_token[0..], expires);
    try ctx.putCookie(cookie);

    const user = try ctx.arena.create(User);
    user.* = User{
        .id = "",
        .name = credentials.name[0..],
        .email = credentials.email[0..],
    };
    user.id = try ctx.arena.dupe(u8, uuid_buf[0..]);
    cache.user_db.put(user.id, user.*) catch {
        try ctx.ERROR(401, "Cache Error: Could not insert");
        return error.InternalServerError;
    };

    _ = ctx.STRING(user.id) catch {
        try ctx.ERROR(401, "Could not send response: input error");
        return error.InternalServerError;
    };
}
