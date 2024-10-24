const std = @import("std");
const Tempest = @import("./tempest/server.zig");
const routes = @import("./tests/routes/index.zig");
const authroutes = @import("./tests/middleware/auth.zig");
const Context = @import("./context/index.zig");
const MiddleFunc = @import("./tempest/server.zig").MiddleFunc;
const HandlerFunc = @import("./tempest/server.zig").HandlerFunc;
const init = @import("./tests/data/index.zig").init;
const initCaches = @import("./tests/init/index.zig").init;
const NimbusPool = @import("./nimbus/NimbusPool.zig");
const Nimbus = @import("./nimbus/index.zig");

pub fn createBackendServer_one(port: u16) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    const allocator = arena.allocator();
    const server_addr = "127.0.0.1";
    const server_port = port;
    const config = Tempest.Config{
        .server_addr = server_addr,
        .server_port = server_port,
        .sticky_server = false,
    };

    try init(allocator);
    var tempest = try Tempest.new(config, allocator);
    defer tempest.deinit();

    try tempest.addRoute("/users", "POST", routes.createUser, &[_]MiddleFunc{authroutes.validate});
    try tempest.addRoute("/users/:id", "GET", routes.getUserById, &[_]MiddleFunc{});
    try tempest.addRoute("/users/:id", "PATCH", routes.updateUser, &[_]MiddleFunc{});
    try tempest.addRoute("/signup", "POST", authroutes.signup, &[_]MiddleFunc{});
    try tempest.addRoute("/pingnimbus", "POST", routes.pingNimbus, &[_]MiddleFunc{});
    try tempest.addRoute("/dllpush", "POST", routes.dllNimbus, &[_]MiddleFunc{});
    try tempest.addRoute("/ping", "POST", routes.ping, &[_]MiddleFunc{});
    // try tempest.addRoute("/users/:name/:id", "GET", routes.getUser);
    try tempest.listen();
}

pub fn createBackendServer_two(port: u16) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    const allocator = arena.allocator();
    const server_addr = "127.0.0.1";
    const server_port = port;
    const config = Tempest.Config{
        .server_addr = server_addr,
        .server_port = server_port,
        .sticky_server = false,
    };

    try init(allocator);
    var tempest = try Tempest.new(config, allocator);
    defer tempest.deinit();

    try tempest.addRoute("/users", "POST", routes.createUser, &[_]MiddleFunc{authroutes.validate});
    try tempest.addRoute("/users/:id", "GET", routes.getUserById, &[_]MiddleFunc{});
    try tempest.addRoute("/users/:id", "PATCH", routes.updateUser, &[_]MiddleFunc{});
    try tempest.addRoute("/signup", "POST", authroutes.signup, &[_]MiddleFunc{});
    try tempest.addRoute("/pingnimbus", "POST", routes.pingNimbus, &[_]MiddleFunc{});
    try tempest.addRoute("/dllpush", "POST", routes.dllNimbus_two, &[_]MiddleFunc{});
    try tempest.addRoute("/ping", "POST", routes.ping, &[_]MiddleFunc{});
    // try tempest.addRoute("/users/:name/:id", "GET", routes.getUser);
    try tempest.listen();
}

pub fn main() !void {
    try initCaches();
    // var nimbus_pool: NimbusPool = undefined;
    // const cache = try nimbus_pool.createNimbus(6379);
    // const cache_2 = try nimbus_pool.createNimbus(6380);
    // var pool = [_]Nimbus{
    //     cache,
    //     cache_2,
    // };
    // try nimbus_pool.init(&pool);
    // try nimbus_pool.test_caches();

    var thread1 = try std.Thread.spawn(.{}, createBackendServer_one, .{8081});
    var thread2 = try std.Thread.spawn(.{}, createBackendServer_two, .{8082});
    thread1.join();
    thread2.join();

    // _ = try std.Thread.spawn(.{}, createBackendServer, .{8082});
}
