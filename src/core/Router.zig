const std = @import("std");

const Node = struct {
    value: []const u8,
    children: std.StringHashMap(*Node),
    is_end: bool,
};

fn newNode(value: []const u8) !*Node {
    const node = try std.heap.page_allocator.create(Node);
    node.* = Node{
        .value = value,
        .children = std.StringHashMap(*Node).init(std.heap.page_allocator),
        .is_end = false,
    };

    return node;
}

pub const Router = struct {
    const Self = @This();
    root: ?*Node,

    pub fn init() !Self {
        const empty_node = try newNode("");
        return Self{
            .root = empty_node,
        };
    }

    pub fn addRoute(self: *Self, path: []const u8) !void {
        var path_iter = std.mem.tokenizeScalar(u8, path, '/');
        std.debug.print("\n{any}\n", .{@TypeOf(path_iter)});
        try self.insert(&path_iter);
    }

    pub fn searchRoute(self: *Self, path: []const u8) bool {
        var path_iter = std.mem.tokenizeScalar(u8, path, '/');
        return self.search(&path_iter);
    }

    fn insert(self: *Self, segments: *std.mem.TokenIterator(u8, .scalar)) !void {
        var node = self.root;
        while (segments.next()) |segment| {
            if (node == null) return;
            const exists = node.?.children.get(segment);
            if (exists == null) {
                const new_node = try newNode(segment);
                try node.?.children.put(segment, new_node);
            }

            node = node.?.children.get(segment);
        }
        node.?.is_end = true;
    }

    fn search(self: *Self, segments: *std.mem.TokenIterator(u8, .scalar)) bool {
        var node = self.root;

        while (segments.next()) |segment| {
            if (node == null) return false;
            const exists = node.?.children.get(segment);
            if (exists == null) return false;
            node = exists;
        }
        return node.?.is_end;
    }
};

test "Insert" {
    var trie = try Router.init();
    try trie.addRoute("/users/posts/:name");
    const isThere = trie.searchRoute("/users/posts");
    std.debug.print("\n{any}\n", .{isThere});
}
