const std = @import("std");
const print = std.debug.print;
const clibpq = @cImport({
    @cInclude("libpq-fe.h");
});

const Self = @This();
conn: *clibpq.PGconn,
conn_str: []const u8,

const PGSQL_Config = struct { conn_str: []const u8 };

pub fn init(target: *Self, config: PGSQL_Config) !void {
    target.* = .{ .conn_str = config.conn_str };
}

pub fn open(self: *Self) !void {
    const conn_info: [:0]const u8 = std.mem.Allocator.dupeZ(self.conn_str);
    const conn = clibpq.PQconnectdb(conn_info);
    if (clibpq.PQstatus(conn) != clibpq.CONNECTION_OK) {
        print("Connect failed, err: {s}\n", .{clibpq.PQerrorMessage(conn)});
        return error.connect;
    }
    self.conn = conn.?;
}

pub fn deinit(self: *Self) void {
    clibpq.PQfinish(self.conn);
}
