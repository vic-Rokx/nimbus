const std = @import("std");
const Context = @import("../context/index.zig");

const HandlerFunc = *const fn (*Context) anyerror!void;
const Node = struct {
    value: ?HandlerFunc,
    query_param: []const u8,
    is_dynamic: bool,
    children: std.StringHashMap(*Node),
    is_end: bool,
};

const ParamInfo = struct { param: []const u8, value: []const u8 };

const ReturnCall = struct {
    handler: ?HandlerFunc,
    param_args: *std.ArrayList(ParamInfo),
};

fn newNode(value: ?HandlerFunc, query_param: []const u8) !*Node {
    const node = try std.heap.page_allocator.create(Node);
    node.* = Node{
        .value = value,
        .query_param = query_param,
        .is_dynamic = false,
        .children = std.StringHashMap(*Node).init(std.heap.page_allocator),
        .is_end = false,
    };

    return node;
}

pub const Router = struct {
    const Self = @This();
    root: ?*Node,

    pub fn init() !Self {
        const empty_node = try newNode(null, "");
        return Self{
            .root = empty_node,
        };
    }

    pub fn addRoute(self: *Self, path: []const u8, handler: HandlerFunc) !void {
        var path_iter = std.mem.tokenizeScalar(u8, path, '/');
        try self.insert(&path_iter, handler);
    }

    pub fn searchRoute(self: *Self, path: []const u8) !?ReturnCall {
        var path_iter = std.mem.tokenizeScalar(u8, path, '/');
        return try self.search(&path_iter);
    }

    fn insert(self: *Self, segments: *std.mem.TokenIterator(u8, .scalar), handler: HandlerFunc) !void {
        var node = self.root;
        while (segments.next()) |segment| {
            if (node == null) return;
            const dynamic = segment[0] == ':';
            const key = if (dynamic) ":dynamic" else segment;
            const exists = node.?.children.get(key) orelse null;
            if (exists == null) {
                const param = if (dynamic) segment[1..] else "";
                const new_node = try newNode(handler, param);
                new_node.is_dynamic = dynamic;
                try node.?.children.put(key, new_node);
            }

            node = node.?.children.get(key);
        }
        node.?.is_end = true;
    }

    fn search(self: *Self, segments: *std.mem.TokenIterator(u8, .scalar)) !?ReturnCall {
        var node = self.root;
        var param_args = std.ArrayList(ParamInfo).init(std.heap.page_allocator);

        while (segments.next()) |segment| {
            if (node == null) return null;
            const exists = node.?.children.get(segment);
            const dynamic = node.?.children.get(":dynamic");
            if (exists != null) {
                node = exists;
            }
            if (dynamic != null) {
                node = dynamic;
                const param_info = ParamInfo{
                    .param = node.?.query_param,
                    .value = segment,
                };
                try param_args.append(param_info);
            }

            if (dynamic == null and exists == null) {
                return null;
            }
        }
        const return_call = ReturnCall{
            .handler = node.?.value,
            .param_args = &param_args,
        };
        return return_call;
    }
};

fn handlePosts(path: []const u8) void {
    std.debug.print("\nHandle user route: {s} \n", .{path});
}
fn handlePostsByName(path: []const u8) void {
    std.debug.print("\nHandle user route by name: {s} \n", .{path});
}

test "Insert" {
    var trie = try Router.init();
    try trie.addRoute("/users/posts/:name", handlePostsByName);
    try trie.addRoute("/users/posts", handlePosts);
    const route = try trie.searchRoute("/users/posts/Vic");
    try std.testing.expect(route != null);
    // std.debug.print("\nroute exists {any}\n", .{isThere});
    std.debug.print("\nroute exists {s}\n", .{route.?.param_args.items[0]});
    // isThere.?.handler("users/routes");
}
