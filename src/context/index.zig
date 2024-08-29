const std = @import("std");
const Parsed = std.json.Parsed;

pub const Self = @This();
allocator: std.mem.Allocator,
params: std.StringHashMap([]const u8), // Array of key-value pairs for URL parameters
query_params: std.StringHashMap([]const u8), // Array of key-value pairs for query parameters
form_params: std.StringHashMap([]const u8), // Array of key-value pairs for form data
method: []const u8,
route: []const u8,
headers: std.StringHashMap([]const u8),
json_payload: []const u8,

pub fn init(allocator: std.mem.Allocator, method: []const u8, route: []const u8) !Self {
    return Self{
        .allocator = allocator,
        .method = method,
        .route = route,
        .params = std.StringHashMap([]const u8).init(allocator),
        .query_params = std.StringHashMap([]const u8).init(allocator),
        .form_params = std.StringHashMap([]const u8).init(allocator),
        .headers = std.StringHashMap([]const u8).init(allocator),
        .json_payload = "Hello",
    };
}

pub fn addParam(self: *Self, key: []const u8, value: []const u8) !void {
    try self.params.put(key, value);
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
    const parsed = std.json.parseFromSlice(
        T,
        self.allocator,
        self.json_payload,
        .{},
    ) catch return error.MalformedJson;
    defer parsed.deinit();

    return parsed.value;
}
