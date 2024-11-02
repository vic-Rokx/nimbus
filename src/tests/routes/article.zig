const std = @import("std");
const Context = @import("../../context/index.zig");
const Article = @import("../models.zig").Article;
const helpers = @import("../../helpers/index.zig");
const caches = @import("../data/index.zig");
pub fn createArticle(ctx: *Context) !void {
    var article = ctx.bind(Article) catch {
        try ctx.ERROR(401, "Failed to bind Struct Type: Article Struct");
        return error.InternalServerError;
    };

    var uuid_buf: [36]u8 = undefined;
    helpers.newV4().to_string(&uuid_buf);
    // We need to allocate memory for the id since the context is removed;
    article.id = try ctx.arena.dupe(u8, uuid_buf[0..]);
    caches.article_db.put(article.id.?, article) catch {
        try ctx.ERROR(401, "Cache Error: Could not insert");
        return error.InternalServerError;
    };
    _ = ctx.STRING(article.id.?) catch {
        try ctx.ERROR(401, "Could not send response: input error");
        return error.InternalServerError;
    };
}

pub fn getArticleById(ctx: *Context) anyerror!void {
    const id = ctx.param("id") catch {
        try ctx.ERROR(401, "Param Error: Could not find param");
        return error.InternalServerError;
    };
    const article = caches.article_db.get(id) catch |err| {
        std.debug.print("\n{}", .{err});
        try ctx.ERROR(401, "Database Error: Value not found");
        return error.InternalServerError;
    };
    _ = ctx.JSON(Article, article) catch {
        try ctx.ERROR(401, "Reponse Error: Could not send JSON response");
        return error.InternalServerError;
    };
}
