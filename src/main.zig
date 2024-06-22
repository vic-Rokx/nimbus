const std = @import("std");
const Tempest = @import("./tempest/server.zig");
const routes = @import("./tests/routes/index.zig");
const init = @import("./tests/data/index.zig").init;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const server_addr = "127.0.0.1";
    const server_port = 8000;
    const config = Tempest.Config{
        .server_addr = server_addr,
        .server_port = server_port,
    };

    try init(allocator);

    var tempest = try Tempest.new(config, allocator);

    try tempest.addRoute("/users", "POST", routes.createUser);
    try tempest.addRoute("/users/:name", "GET", routes.getUser);
    try tempest.listen();
}
