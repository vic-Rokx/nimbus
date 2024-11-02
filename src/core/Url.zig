const std = @import("std");
// const utils = @import("../utils/index.zig");
// const Self = @This();
// arena: *std.mem.Allocator,

const QueryParam = struct {
    key: []const u8,
    value: []const u8,
};

pub const QueryBuilder = struct {
    query_param_list: std.ArrayList(*QueryParam),
    arena: *std.mem.Allocator,
    str: []const u8,
    pub fn init(target: *QueryBuilder, arena: *std.mem.Allocator) !void {
        var query_param_list_arr: std.ArrayList(*QueryParam) = undefined;
        query_param_list_arr = std.ArrayList(*QueryParam).init(arena.*);
        target.* = .{
            .query_param_list = query_param_list_arr,
            .arena = arena,
            .str = "",
        };
    }

    /// This function parses the value and replaces ' ' => '+' if necessary.
    ///
    /// # Parameters:
    /// - `key`: []const u8.
    /// - `value`: []const u8.
    ///
    /// # Returns:
    /// void and adds to query builder list.
    pub fn add(self: *QueryBuilder, key: []const u8, value: []const u8) !void {
        // utils.assert_cm(self.query_param_list.capacity > 0, "QueryBuilder not initilized");
        var value_itr = std.mem.splitScalar(u8, value, ' ');
        _ = value_itr.next();
        if (value_itr.peek() == null) {
            const query_param = try self.arena.*.create(QueryParam);
            query_param.* = QueryParam{ .key = key, .value = value };
            try self.query_param_list.append(query_param);
        } else {
            value_itr.reset();
            const parsed_value = try self.arena.*.alloc(u8, value.len);
            var idx: u16 = 0;
            var padding: usize = 0;
            while (idx < value.len) {
                const sub_str = value_itr.next();
                if (sub_str == null) break;
                for (sub_str.?, 0..) |c, i| {
                    parsed_value[padding + i] = c;
                    idx += 1;
                }
                if (value_itr.peek() == null) break;
                padding = padding + sub_str.?.len;
                parsed_value[padding] = '+';
                padding += 1;
                idx += 1;
            }
            const query_param = try self.arena.*.create(QueryParam);
            query_param.* = QueryParam{ .key = key, .value = parsed_value[0..] };
            try self.query_param_list.append(query_param);
        }
    }

    pub fn remove(self: *QueryBuilder, key: []const u8) !void {
        // utils.assert_cm(self.query_param_list.capacity > 0, "QueryBuilder not initilized");
        for (self.*.query_param_list.items, 0..) |query_param, i| {
            std.debug.print("\n:{s}", .{query_param.value});
            if (std.mem.eql(u8, query_param.key, key)) {
                _ = self.query_param_list.orderedRemove(i);
                break;
            }
        }
    }

    pub fn deinit(self: *QueryBuilder) void {
        for (self.query_param_list.items) |query_param| {
            self.arena.*.destroy(query_param);
        }
        self.query_param_list.deinit();
    }

    pub fn queryStrEncode(self: *QueryBuilder) !void {
        var query_str_slice = try self.arena.*.alloc(
            []const u8,
            self.query_param_list.items.len * 2 * 2,
        );

        defer self.arena.free(query_str_slice);
        var idx: u16 = 0;
        for (self.query_param_list.items) |query_param| {
            query_str_slice[idx] = "&";
            idx += 1;
            query_str_slice[idx] = query_param.key;
            idx += 1;
            query_str_slice[idx] = "=";
            idx += 1;
            query_str_slice[idx] = query_param.value;
            idx += 1;
        }
        const str = try std.mem.join(self.arena.*, "", query_str_slice);
        self.str = str[0..];
    }

    pub fn generateUrl(self: *QueryBuilder, url: []const u8, addition: []const u8) ![]const u8 {
        var builder = try std.RingBuffer.init(self.arena.*, 1024);
        defer builder.deinit(self.arena.*);
        try builder.writeSlice(url);
        try builder.write('?');
        try builder.writeSlice(addition[1..]);

        const s = try std.heap.c_allocator.alloc(u8, builder.len());
        std.mem.copyForwards(u8, s, builder.data[0..builder.len()]);
        return s;
    }

    pub fn urlEncoder(self: *QueryBuilder, url: []const u8) ![]const u8 {
        var builder = try std.RingBuffer.init(self.arena.*, 1024);
        for (url) |char| {
            switch (char) {
                ' ' => {
                    try builder.writeSlice("%20");
                },
                '!' => {
                    try builder.writeSlice("%21");
                },
                // '\' => { return "%22"; },
                '#' => {
                    try builder.writeSlice("%23");
                },
                '$' => {
                    try builder.writeSlice("%24");
                },
                '%' => {
                    try builder.writeSlice("%25");
                },
                '&' => {
                    try builder.writeSlice("%26");
                },
                // ''' => { return "%27"; },
                '(' => {
                    try builder.writeSlice("%28");
                },
                ')' => {
                    try builder.writeSlice("%29");
                },
                '*' => {
                    try builder.writeSlice("%2A");
                },
                '+' => {
                    try builder.writeSlice("%2B");
                },
                ',' => {
                    try builder.writeSlice("%2C");
                },
                '/' => {
                    try builder.writeSlice("%2F");
                },
                ':' => {
                    try builder.writeSlice("%3A");
                },
                ';' => {
                    try builder.writeSlice("%3B");
                },
                '=' => {
                    try builder.writeSlice("%3D");
                },
                '?' => {
                    try builder.writeSlice("%3F");
                },
                '@' => {
                    try builder.writeSlice("%40");
                },
                '[' => {
                    try builder.writeSlice("%5B");
                },
                ']' => {
                    try builder.writeSlice("%5D");
                },
                '{' => {
                    try builder.writeSlice("%7B");
                },
                '}' => {
                    try builder.writeSlice("%7D");
                },
                '|' => {
                    try builder.writeSlice("%7C");
                },
                '~' => {
                    try builder.writeSlice("%7E");
                },
                else => try builder.write(
                    char,
                ),
            }
        }

        const s = try std.heap.c_allocator.alloc(u8, builder.len());
        std.mem.copyForwards(u8, s, builder.data[0..builder.len()]);
        return s;
    }
};

// https://accounts.google.com/o/oauth2/v2/auth?client_id=your-google-client-id&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fauth%2Fcallback&response_type=code&scope=openid+email+profile&access_type=offline&prompt=consent
test "test add remove and encode" {
    var query: QueryBuilder = undefined;
    var arena = std.heap.c_allocator;
    try query.init(&arena);
    try query.add("client_id", "98f3$j%gw54u4562$");

    const encoded_url = try query.urlEncoder("https://accounts.google.com/o/oauth2/v2/auth");

    try query.add("redirect_url", encoded_url);
    try query.add("response_type", "code");
    try query.add("scope", "8904qfyhiu v.rokx.nellemann@gmail.com vicrokx");
    try query.add("access_type", "offline");
    try query.add("prompt", "consent");

    try query.queryStrEncode();
    const full_url = try query.generateUrl("https://accounts.google.com/o/oauth2/v2/auth", query.str);
    std.debug.print("\nurl_query: {s}\n", .{full_url});
}
