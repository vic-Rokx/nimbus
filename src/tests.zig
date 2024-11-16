const std = @import("std");
const Nimbus = @import("./nimbus/server.zig");
const Context = @import("./context/index.zig");
const MiddleFunc = @import("./nimbus/server.zig").MiddleFunc;
const HandlerFunc = @import("./nimbus/server.zig").HandlerFunc;
fn testRouteFunc(ctx: *Context) !void {
    std.debug.print("Route:{s}\n", .{ctx.route});
    return;
}

test "addRoute" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    var allocator = arena.allocator();
    const server_addr = "127.0.0.1";
    const server_port = 8080;
    const config = Nimbus.Config{
        .server_addr = server_addr,
        .server_port = server_port,
        .sticky_server = false,
    };

    var nimbus: Nimbus = undefined;
    try nimbus.new(config, &allocator);
    defer nimbus.deinit();
    try nimbus.addRoute("/users/:id", "PATCH", testRouteFunc, &[_]MiddleFunc{});
}
