const std = @import("std");
const print = std.debug.print;

const Self = @This();
ring_builder: std.RingBuffer,
arena: *std.mem.Allocator,

fn assert(ok: bool, comptime error_msg: []const u8) void {
    if (!ok) {
        const boldRed = "\x1b[1;31m"; // ANSI escape code for bold + red
        const reset = "\x1b[0m"; // Reset ANSI code to clear formatting
        std.debug.print("\n{s}Error{s}: ", .{ boldRed, reset });
        std.debug.print("{s}\n", .{error_msg});
        // @compileError(error_msg);
        unreachable; // assertion failure
    }
}

pub fn init(target: *Self, arena: *std.mem.Allocator, capacity: u16) !void {
    target.* = .{
        .ring_builder = try std.RingBuffer.init(arena.*, capacity),
        .arena = arena,
    };
}

pub fn deinit(self: *Self) void {
    self.ring_builder.deinit();
}

pub fn addLine(self: *Self, sql_line: []const u8) !void {
    try self.ring_builder.writeSlice(sql_line);
    try self.ring_builder.writeSlice(", ");
}

pub fn printRingBuff(self: *Self) void {
    print("{s}\n", .{self.ring_builder.data[0..self.ring_builder.len()]});
}

// -- Create a table with various data types including UUID
// CREATE TABLE users (
//     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
//     username VARCHAR(50) UNIQUE NOT NULL,
//     email VARCHAR(100) UNIQUE NOT NULL,
//     created_at TIMESTAMP DEFAULT NOW(),
//     updated_at TIMESTAMP DEFAULT NOW()
// );

pub fn createTable(self: *Self, comptime T: type) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    try self.ring_builder.writeSlice("CREATE TABLE ");

    // var writer = std.io.AnyWriter;
    const fields = @typeInfo(T).Struct.fields;
    const table_name = T.Table;
    // const table_name = @field(T, "Table");
    try self.ring_builder.writeSlice(table_name);
    try self.ring_builder.writeSlice(" (\n");
    self.printRingBuff();
    // we need to parse the struct []const u8 into []u8 to store in the hashmap
    inline for (fields) |f| {
        const field_type = f.type;
        try self.ring_builder.writeSlice(f.name);
        // const field_value = @field(T, f.name);
        // print("{any} (u32)\n", .{field_value});
        switch (field_type) {
            []const u8 => print("TEXT\n", .{}),
            u32 => print("INTEGER (u32)\n", .{}),
            i32 => print("INTEGER (i32)\n", .{}),
            f64 => print("REAL (f64)\n", .{}),
            bool => print("BOOLEAN\n", .{}),
            u8 => print("CHARACTER (u8)\n", .{}),
            u16 => print("INTEGER (u16)\n", .{}),
            i64 => print("BIGINT (i64)\n", .{}),
            usize => print("BIGINT (usize)\n", .{}),
            else => print("UNSUPPORTED TYPE\n", .{}),
        }
        // const field_value = @field(parsed.value, f.name);
        // @field(parsed.value, f.name) = try helpers.convertStringToSlice(field_value, std.heap.c_allocator);
    }

    try self.ring_builder.writeSlice(");");
}

test "create table" {
    var arena = std.heap.c_allocator;
    const User = struct {
        // required declarations used by the orm
        pub const Table = "test_table";
        pub const Allocator = std.testing.allocator;

        const column = struct {
            type: "uuid",
            primaryKey: undefined,
            default: "uuid_generate_v4",
        };
        test_value: []const u8,
        test_num: u32,
        test_bool: bool,
    };
    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);

    try zorm.createTable(User);
    // var new_user = User{ .test_value = "foo", .test_num = 42, .test_bool = true };
    // try Self.insert(User, new_user).send();
}
