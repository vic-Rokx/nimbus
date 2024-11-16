const std = @import("std");
// const utils = @import("../utils/index.zig");

const Param = struct {
    key: []const u8,
    value: []const u8,
};

const QueryBuilder = @This();
arena: std.mem.Allocator,
params: std.ArrayList(Param),
str: []const u8,

/// This function takes a pointer to this QueryBuilder instance.
/// Deinitializes the query builder instance
/// # Parameters:
/// - `target`: *QueryBuilder.
/// - `arena`: std.mem.Allocator.
///
/// # Returns:
/// void.
pub fn init(query_builder: *QueryBuilder, arena: std.mem.Allocator) !void {
    query_builder.* = .{
        .arena = arena,
        .params = std.ArrayList(Param).init(arena),
        .str = "",
    };
}

/// This function takes a pointer to this QueryBuilder instance.
/// Deinitializes the query builder instance, loops over the keys and values to free
/// # Parameters:
/// - `target`: *QueryBuilder.
///
/// # Returns:
/// void.
pub fn deinit(query_builder: *QueryBuilder) void {
    for (query_builder.params.items) |param| {
        query_builder.arena.free(param.key);
        query_builder.arena.free(param.value);
    }
    query_builder.params.deinit();
    if (query_builder.str.len > 0) {
        query_builder.arena.free(query_builder.str);
    }
}

/// This function adds a value and key to the query builder.
/// # Example
/// try query.add("client_id", "98f3$j%gw54u4562$");
///
/// # Parameters:
/// - `key`: []const u8.
/// - `value`: []const u8.
///
/// # Returns:
/// void and adds to query builder list.
pub fn add(query_builder: *QueryBuilder, key: []const u8, value: []const u8) !void {
    const key_dup = try query_builder.arena.dupe(u8, key);
    const value_dup = try query_builder.arena.dupe(u8, value);
    try query_builder.params.append(.{ .key = key_dup, .value = value_dup });
}

/// This function removes a key.
/// # Example
/// try query.remove("client_id");
///
/// # Parameters:
/// - `key`: []const u8.
///
/// # Returns:
/// void
pub fn remove(query_builder: *QueryBuilder, key: []const u8) !void {
    // utils.assert_cm(query_builder.query_param_list.capacity > 0, "QueryBuilder not initilized");
    for (query_builder.params.items, 0..) |query_param, i| {
        if (std.mem.eql(u8, query_param.key, key)) {
            _ = query_builder.query_param_list.orderedRemove(i);
            break;
        }
    }
}

/// This function encodes the url pass.
/// # Example
/// try query.urlEncoder("https://accounts.google.com/o/oauth2/v2/auth");
///
/// # Parameters:
/// - `url`: []const u8.
///
/// # Returns:
/// []const u8
pub fn urlEncoder(query_builder: *QueryBuilder, url: []const u8) ![]const u8 {
    var encoded = std.ArrayList(u8).init(query_builder.arena);
    defer encoded.deinit();

    for (url) |c| {
        switch (c) {
            'a'...'z', 'A'...'Z', '0'...'9', '-', '_', '.', '~' => try encoded.append(c),
            ' ' => try encoded.append('+'),
            else => {
                try encoded.writer().print("%{X:0>2}", .{c});
            },
        }
    }

    return encoded.toOwnedSlice();
}

/// This function encodes the query and set query_builder.str.
/// # Example
/// try query.queryStrEncode();
///
/// # Returns:
/// void
pub fn queryStrEncode(query_builder: *QueryBuilder) !void {
    if (query_builder.params.items.len == 0) {
        query_builder.str = "";
        return;
    }

    var list = std.ArrayList(u8).init(query_builder.arena);
    errdefer list.deinit();

    for (query_builder.params.items, 0..) |param, i| {
        if (i > 0) {
            try list.append('&');
        }

        // URL encode key
        const encoded_key = try query_builder.urlEncoder(param.key);
        defer query_builder.arena.free(encoded_key);
        try list.appendSlice(encoded_key);

        try list.append('=');

        // URL encode value
        const encoded_value = try query_builder.urlEncoder(param.value);
        defer query_builder.arena.free(encoded_value);
        try list.appendSlice(encoded_value);
    }

    query_builder.str = try list.toOwnedSlice();
}

/// This function generates the queried url plus the precursor url.
/// # Example
/// try query.generateUrl("https://accounts.google.com/o/oauth2/v2/auth", query.str);
///
/// # Parameters:
/// - `base_url`: []const u8.
/// - `query`: []const u8.
///
/// # Returns:
/// []const u8
pub fn generateUrl(query_builder: *QueryBuilder, base_url: []const u8, query: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(query_builder.arena);
    errdefer result.deinit();

    try result.appendSlice(base_url);
    if (query.len > 0) {
        try result.append('?');
        try result.appendSlice(query);
    }

    return result.toOwnedSlice();
}

// Helper function to get parameters in order
pub fn getParams(query_builder: *QueryBuilder) []const Param {
    return query_builder.params.items;
}

// https://accounts.google.com/o/oauth2/v2/auth?client_id=your-google-client-id&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fauth%2Fcallback&response_type=code&scope=openid+email+profile&access_type=offline&prompt=consent
// https://accounts.google.com/o/oauth2/v2/auth?client_id=98f3%24j%25gw54u4562%24&redirect_url=https%253A%252F%252Faccounts.google.com%252Fo%252Foauth2%252Fv2%252Fauth&response_type=code&scope=8904qfyhiu+v.rokx.nellemann%40gmail.com+vicrokx&access_type=offline&prompt=consent
// https://accounts.google.com/o/oauth2/v2/auth?client_id=98f3$j%gw54u4562$&redirect_url=https%3A%2F%2Faccounts.google.com%2Fo%2Foauth2%2Fv2%2Fauth&response_type=code&scope=8904qfyhiu+v.rokx.nellemann@gmail.com+vicrokx&access_type=offline&prompt=consent
test "test add remove and encode" {
    var query: QueryBuilder = undefined;
    var arena = std.heap.c_allocator;
    try query.init(arena);
    defer query.deinit();

    try query.add("client_id", "98f3$j%gw54u4562$");

    const encoded_url = try query.urlEncoder("https://accounts.google.com/o/oauth2/v2/auth");
    defer arena.free(encoded_url);

    try query.add("redirect_url", encoded_url);
    try query.add("response_type", "code");
    try query.add("scope", "8904qfyhiu v.rokx.nellemann@gmail.com vicrokx");
    try query.add("access_type", "offline");
    try query.add("prompt", "consent");

    try query.queryStrEncode();
    const full_url = try query.generateUrl("https://accounts.google.com/o/oauth2/v2/auth", query.str);
    defer arena.free(full_url);

    std.debug.print("\nurl_query: {s}\n", .{full_url});
}
