const std = @import("std");
const Context = @import("../../context/index.zig");
const Article = @import("../models.zig").Article;
const helpers = @import("../../helpers/index.zig");
const caches = @import("../data/index.zig");
const DB = @import("../../pgsql/clibpq.zig").DB;

fn createTable(tableName: []const u8, columns: []const []const u8) ![]const u8 {
    const sql = try std.fmt.allocPrint(std.heap.c_allocator, "CREATE TABLE IF NOT EXISTS {s} (", .{tableName});

    var builder = try std.RingBuffer.init(std.heap.page_allocator, 1024);
    try builder.writeSlice(sql);
    try builder.writeSlice("\r\n");

    for (columns, 0..) |col, i| {
        try builder.writeSlice(col);
        if (i < columns.len - 1) {
            try builder.writeSlice(", ");
        }
        try builder.writeSlice("\r\n");
    }

    try builder.writeSlice(");");
    return builder.data[0..builder.len()];
}

pub fn createDB(ctx: *Context) !void {
    const conn_info = "host=localhost user=postgres password=development dbname=postgres port=5432 sslmode=disable";
    const db = try DB.init(conn_info);
    const catColorsColumns = [_][]const u8{
        "id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY",
        "name TEXT NOT NULL UNIQUE",
    };

    const resp = try createTable("cat_colors", &catColorsColumns);
    const pointer_slice: [:0]const u8 = try std.mem.Allocator.dupeZ(std.heap.c_allocator, u8, resp);
    try db.exec(pointer_slice);
    // try db.exec(
    //     \\ create table if not exists cat_colors (
    //     \\   id integer primary key generated always as identity,
    //     \\   name text not null unique
    //     \\ );
    //     \\ create table if not exists cats (
    //     \\   id integer primary key generated always as identity,
    //     \\   name text not null,
    //     \\   color_id integer not null references cat_colors(id)
    //     \\ );
    // );

    // try db.insertTable();
    // try db.queryTable();
    // try db.dropTable();

    // try db.exec(
    //     \\ DROP TABLE IF EXISTS cat_colors CASCADE
    // );

    defer db.deinit();

    _ = ctx.STRING("SUCCESS") catch {
        try ctx.ERROR(401, "Could not send response: input error");
        return error.InternalServerError;
    };
}

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
