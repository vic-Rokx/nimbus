const std = @import("std");
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

// Usage
test "create table" {
    const catColorsColumns = [_][]const u8{
        "id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY",
        "name TEXT NOT NULL UNIQUE",
    };

    const resp = try createTable("cat_colors", &catColorsColumns);
    const actual =
        \\CREATE TABLE IF NOT EXISTS cat_colors (
        \\id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        \\name TEXT NOT NULL UNIQUE,
        \\);
    ;

    var builder = try std.RingBuffer.init(std.heap.page_allocator, 1024);
    try builder.writeSlice("ropqiekjhefpa");
    const tr = builder.data[0..builder.len()];
    const tr_v: [:0]const u8 = try std.mem.Allocator.dupeZ(std.heap.c_allocator, u8, tr);
    std.debug.print("\n\n{s}", .{resp});
    std.debug.print("\n\n{s}", .{tr_v});
    std.debug.print("\n\n{s}", .{tr});
    std.debug.print("\n\n{s}", .{actual});
    // try std.testing.expect(std.mem.eql(u8, resp, actual));
}
