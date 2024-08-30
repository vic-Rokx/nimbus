const routes = @import("../tests/routes/index");
const std = @import("std");
const Context = @import("../context/index.zig");

const HandlerFunc = *const fn (path: []const u8) void;

const Radix = struct {
    const Self = @This();
    value: ?HandlerFunc,
    is_dynamic: bool,
    children: std.StringHashMap(*Radix),

    pub fn init(allocator: std.mem.Allocator) Radix {
        return Self{
            .value = null,
            .children = std.StringHashMap(*Self).init(allocator),
            .is_dynamic = false,
        };
    }

    pub fn insert(self: *Self, path: []const u8, handler: HandlerFunc) !*Radix {
        var segments = std.mem.splitScalar(u8, path, '/');
        var node = self;
        // var seg = path;

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
        node.value = handler;
        return node;
    }

    pub fn search(self: *Self, path: []const u8) ?*Radix {
        var segments = std.mem.tokenizeScalar(u8, path, '/');
        const node = self;
        return searchImpl(node, &segments);
    }

    fn searchImpl(node: ?*Self, segments: *std.mem.TokenIterator(u8, .scalar)) ?*Radix {
        var child_node = node;
        var count: usize = 0;

        while (segments.next()) |segment| {
            if (child_node == null) return null;
            if (child_node.?.value != null) {
                std.debug.print("\nThis is the segment {s}", .{segment});
            }
            const exists = child_node.?.children.get(segment);
            std.debug.print("\ncount {d}", .{count});
            count += 1;
            if (exists != null) {
                child_node = exists;
            }
            // std.debug.print("\n\nThis is the segment func {any}", .{exists.?.*.value});
        }
        // if (child_node.?.value != null) {
        //     std.debug.print("\nThis is the segment {any}", .{child_node.?.value});
        // }
        return node;

        // const segment = segments.next();
        // // const remaining_segments = segments[(segments.index + 1)..];
        //
        // const child_node = node.children.get(segment.?) orelse null;
        //
        // if (child_node != null) {
        //     const result = searchImpl(child_node.?, segments);
        //     if (result != null) {
        //         result.?("laksdjflkaf");
        //         return result;
        //     }
        // }
        // const dynamic_node = node.children.get(":dynamic") orelse null;
        //
        // if (dynamic_node != null) {
        //     return searchImpl(dynamic_node.?, segments);
        // }

    }
};

fn handleUser(_: []const u8) void {
    std.debug.print("\nHandle user route: \n", .{});
}

fn handlePosts(path: []const u8) void {
    std.debug.print("\nHandle user route: {s} \n", .{path});
}

test "Radix create insert and search" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var radix = Radix.init(allocator);

    // try radix.insert("users/:name", handleUser);
    const func = try radix.insert("users/posts", handlePosts);
    func.*.value.?("fasdfasF");

    _ = radix.search("users/posts");
    // if (handler1 != null) {
    // handler1.?.*.value.?("fasdfasF");
    // handler1.?("user");
    // }
    // try std.testing.expect(handler1 != null);
    // std.debug.print("\nThis is the segment {any}\n", .{handler1.?});
    // handler1.?("user/john");
}
