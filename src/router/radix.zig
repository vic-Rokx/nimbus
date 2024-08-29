const routes = @import("../tests/routes/index");
const std = @import("std");
const Context = @import("../context/index.zig");

const HandlerFunc = fn (path: []const u8) void;

const Radix = struct {
    const Self = @This();
    value: ?*HandlerFunc,
    is_dynamic: bool,
    children: std.StringHashMap(*Radix),

    pub fn init(allocator: std.mem.Allocator) Radix {
        return Self{
            .value = null,
            .children = std.StringHashMap(*Self).init(allocator),
            .is_dynamic = false,
        };
    }

    pub fn insert(self: *Self, path: []const u8, handler: HandlerFunc) !void {
        var segments = std.mem.splitScalar(u8, path, '/');
        var node = self;

        while (segments.next()) |segment| {
            if (segment.len == 0) continue;
            const dynamic = segment[0] == ':';
            const key = if (dynamic) ":dynamic" else segment;
            var child_node = node.children.get(key) orelse null;

            if (child_node == null) {
                var new_node = Radix.init(node.children.allocator);
                new_node.is_dynamic = dynamic;
                node.children.put(key, &new_node) catch unreachable;
                child_node = &new_node;
            }
            node = child_node.?;
        }
        node.value = &handler;
    }

    pub fn search(self: *Self, path: []const u8) ?*HandlerFunc {
        var segments = std.mem.splitScalar(u8, path, '/');
        const node = self;
        return searchImpl(node, &segments);
    }

    fn searchImpl(node: *Self, segments: []const []const u8) ?*HandlerFunc {
        if (segments.len == 0) {
            return node.value;
        }

        const segment = segments[0];
        const remaining_segments = segments[1..];

        const child_node = node.children.get(segment) orelse null;

        if (child_node != null) {
            const result = searchImpl(child_node.*, remaining_segments);
            if (result != null) return result;
        }
        const dynamic_node = node.children.get(":dynamic") orelse null;

        if (dynamic_node != null) {
            return searchImpl(dynamic_node.*, remaining_segments);
        }

        return null;
    }
};

fn handleUser(path: []const u8) void {
    std.debug.print("Handle user route: {}\n", .{path});
}

fn handlePosts(path: []const u8) void {
    std.debug.print("Handle posts route: {}\n", .{path});
}

test "Radix create insert and search" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var radix = Radix.init(allocator);

    try radix.insert("users/:name", handleUser);
    try radix.insert("users/posts", handlePosts);

    const handler1 = radix.search("user/john");
    try std.testing.expect(handler1 != null);
    // handler1("user/john");
}
