const std = @import("std");
const mem = std.mem;
const Context = @import("../context/index.zig");

const HandlerFunc = *const fn (*Context) anyerror!void;
const MiddleFunc = *const fn (HandlerFunc, *Context) anyerror!HandlerFunc;

// const HandlerFunc = *const fn ([]const u8) void;
// const MiddleFunc = *const fn (HandlerFunc, []const u8) HandlerFunc;

const RadixError = error{
    FailedToInitRadix,
    FailedToCreateNode,
};

const RouteFunc = struct {
    handler_func: HandlerFunc,
    middlewares: []const MiddleFunc,
};

const Node = struct {
    value: ?RouteFunc,
    query_param: []const u8,
    is_dynamic: bool,
    children: std.StringHashMap(*Node),
    is_end: bool,
};

const ParamInfo = struct { param: []const u8, value: []const u8 };

const ReturnCall = struct {
    route_func: ?RouteFunc,
    param_args: *std.ArrayList(ParamInfo),
};

fn newNode(allocator: mem.Allocator, value: ?RouteFunc, query_param: []const u8) !*Node {
    const node = try allocator.create(Node);
    node.* = Node{
        .value = value,
        .query_param = query_param,
        .is_dynamic = false,
        .children = std.StringHashMap(*Node).init(allocator),
        .is_end = false,
    };

    return node;
}

pub const Router = struct {
    const Self = @This();
    allocator: mem.Allocator,
    root: ?*Node,

    pub fn init(allocator: mem.Allocator) !Self {
        const empty_node = try newNode(allocator, null, "");
        return Self{
            .allocator = allocator,
            .root = empty_node,
        };
    }

    pub fn deinit(self: *Self) !void {
        var key_it = self.root.?.children.keyIterator();
        var node = self.root;
        while (key_it.next()) |key| {
            const exists = node.?.children.get(key.*).?;
            try self.recurseDestroy(exists);
        }
        var it = node.?.children.iterator();
        while (it.next()) |entry| {
            self.allocator.destroy(entry.value_ptr);
        }
    }
    pub fn recurseDestroy(self: *Self, node: ?*Node) !void {
        var key_it = node.?.children.keyIterator();
        while (key_it.next()) |key| {
            const exists = node.?.children.get(key.*).?;
            try self.recurseDestroy(exists);
            var it = node.?.children.iterator();
            while (it.next()) |entry| {
                self.allocator.destroy(entry.value_ptr);
            }
        }
    }

    pub fn addRoute(self: *Self, path: []const u8, handler: HandlerFunc, middlewares: []const MiddleFunc) !void {
        var path_iter = mem.tokenizeScalar(u8, path, '/');
        try self.insert(&path_iter, handler, middlewares);
    }

    pub fn searchRoute(self: *Self, path: []const u8) !?ReturnCall {
        var path_iter = mem.tokenizeScalar(u8, path, '/');
        return try self.search(&path_iter);
    }

    fn insert(self: *Self, segments: *mem.TokenIterator(u8, .scalar), handler: HandlerFunc, middlewares: []const MiddleFunc) !void {
        var node = self.root;
        while (segments.next()) |segment| {
            if (node == null) return;
            const dynamic = segment[0] == ':';
            const key = if (dynamic) ":dynamic" else segment;
            const exists = node.?.children.get(key) orelse null;
            if (exists == null) {
                const param = if (dynamic) segment[1..] else "";
                const route_func = RouteFunc{
                    .handler_func = handler,
                    .middlewares = middlewares,
                };
                const new_node = try newNode(self.allocator, route_func, param);
                new_node.is_dynamic = dynamic;
                try node.?.children.put(key, new_node);
            }

            node = node.?.children.get(key);
        }
        node.?.is_end = true;
    }

    fn search(self: *Self, segments: *mem.TokenIterator(u8, .scalar)) !?ReturnCall {
        var node = self.root;
        var param_args = std.ArrayList(ParamInfo).init(self.allocator);

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
            .route_func = node.?.value,
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
    var trie = try Router.init(std.heap.page_allocator);
    try trie.addRoute("/users/posts/:name", handlePostsByName, &[_]MiddleFunc{});
    try trie.addRoute("/users/posts/:name/:id", handlePostsByName, &[_]MiddleFunc{});
    try trie.addRoute("/users/posts", handlePosts, &[_]MiddleFunc{});
    const route = try trie.searchRoute("/users/posts/Vic");
    try std.testing.expect(route != null);
    // std.debug.print("\nroute exists {any}\n", .{isThere});
    // std.debug.print("\nroute exists {s}\n", .{route.?.param_args.items[0]});
    // isThere.?.handler("users/routes");
}
