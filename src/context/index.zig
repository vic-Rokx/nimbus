const std = @import("std");
const net = std.net;
const mem = std.mem;
const Parsed = std.json.Parsed;
const WriterHandler = *const fn ([]const u8) net.Stream.WriteError!usize;
const helpers = @import("../helpers/index.zig");

pub const Self = @This();
allocator: std.mem.Allocator,
params: std.StringHashMap([]const u8), // Array of key-value pairs for URL parameters
query_params: std.StringHashMap([]const u8), // Array of key-value pairs for query parameters
form_params: std.StringHashMap([]const u8), // Array of key-value pairs for form data
method: []const u8,
route: []const u8,
headers: std.StringHashMap([]const u8),
json_payload: []const u8,
conn: net.Server.Connection,

pub fn init(allocator: mem.Allocator, method: []const u8, route: []const u8, conn: net.Server.Connection) !Self {
    return Self{
        .allocator = allocator,
        .method = method,
        .route = route,
        .params = std.StringHashMap([]const u8).init(allocator),
        .query_params = std.StringHashMap([]const u8).init(allocator),
        .form_params = std.StringHashMap([]const u8).init(allocator),
        .headers = std.StringHashMap([]const u8).init(allocator),
        .json_payload = undefined,
        .conn = conn,
    };
}

pub fn deinit(self: *Self) !void {
    // Free the dynamically allocated memory for all hashmaps

    // Free params
    var it = self.params.iterator();
    while (it.next()) |entry| {
        self.allocator.destroy(entry.value_ptr);
    }
    self.params.deinit();

    // Free query_params
    it = self.query_params.iterator();
    while (it.next()) |entry| {
        self.allocator.destroy(entry.value_ptr);
    }
    self.query_params.deinit();

    // Free form_params
    it = self.form_params.iterator();
    while (it.next()) |entry| {
        self.allocator.destroy(entry.value_ptr);
    }
    self.form_params.deinit();

    // Free headers
    it = self.headers.iterator();
    while (it.next()) |entry| {
        self.allocator.destroy(entry.value_ptr);
    }
    self.headers.deinit();

    // Free json_payload if it was dynamically allocated (assuming it may be heap-allocated)
    if (self.json_payload.len > 0) {
        self.allocator.free(self.json_payload);
    }
}

pub fn addParam(self: *Self, key: []const u8, value: []const u8) !void {
    try self.params.put(key, value);
}

pub fn STRING(self: *Self, string: []const u8) !void {
    const stt = "HTTP/1.1 200 Success \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: {}\r\n" ++
        "\r\n" ++
        "{s}";
    const response = std.fmt.allocPrint(
        std.heap.c_allocator,
        stt,
        .{ string.len, string },
    ) catch unreachable;
    _ = try self.conn.stream.write(response);
}

pub fn JSON(self: *Self, comptime T: type, data: T) !void {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var string = std.ArrayList(u8).init(fba.allocator());
    defer string.deinit();
    try std.json.stringify(data, .{}, string.writer());
    const stt = "HTTP/1.1 200 Success \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: application/json; charset=utf8\r\n" ++
        "Content-Length: {}\r\n" ++
        "\r\n" ++
        "{s}";
    const response = std.fmt.allocPrint(
        std.heap.c_allocator,
        stt,
        .{ string.items.len, string.items },
    ) catch unreachable;
    _ = try self.conn.stream.write(response);
}

pub fn param(self: *Self, key: []const u8) ![]const u8 {
    const value = self.params.get(key);
    if (value == null) {
        return error.NoKeyValuePair;
    }
    return value.?;
}

pub fn setJson(self: *Self, haystack: []const u8) !void {
    const payload_start = std.mem.indexOf(u8, haystack, "\r\n\r\n") orelse {
        std.debug.print("Failed to find payload start.\n", .{});
        return error.PostFailed;
    } + 4; // Skip the "\r\n\r\n"
    const json_payload = haystack[payload_start..];
    self.json_payload = json_payload;
}

pub fn bind(self: *Self, comptime T: type) !T {
    const fields = @typeInfo(T).Struct.fields;
    var parsed = std.json.parseFromSlice(
        T,
        self.allocator,
        self.json_payload,
        .{},
    ) catch return error.MalformedJson;
    defer parsed.deinit();
    inline for (fields) |f| {
        if (f.type == []const u8) {
            const field_value = @field(parsed.value, f.name);
            @field(parsed.value, f.name) = try helpers.convertStringToSlice(field_value, std.heap.c_allocator);
        }
    }
    return parsed.value;
}
