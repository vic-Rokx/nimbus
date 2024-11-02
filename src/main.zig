const std = @import("std");
const Nimbus = @import("./nimbus/server.zig");
const routes = @import("./tests/routes/index.zig");
const articleroutes = @import("./tests/routes/article.zig");
const authroutes = @import("./tests/routes/auth.zig");
const mdauthroutes = @import("./tests/middleware/auth.zig");
const Context = @import("./context/index.zig");
const MiddleFunc = @import("./nimbus/server.zig").MiddleFunc;
const HandlerFunc = @import("./nimbus/server.zig").HandlerFunc;
const init = @import("./tests/data/index.zig").init;
const initCaches = @import("./tests/init/index.zig").init;

pub fn createBackendServer_one(port: u16) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    var allocator = arena.allocator();
    const server_addr = "127.0.0.1";
    const server_port = port;
    const config = Nimbus.Config{
        .server_addr = server_addr,
        .server_port = server_port,
        .sticky_server = false,
    };

    try init(allocator);
    var nimbus: Nimbus = undefined;
    try nimbus.new(config, &allocator);
    defer nimbus.deinit();

    try nimbus.addRoute(
        "/users/:id",
        "GET",
        routes.getUserById,
        &[_]MiddleFunc{mdauthroutes.verifyAuth},
    );
    try nimbus.addRoute(
        "/articles/:id",
        "GET",
        articleroutes.getArticleById,
        &[_]MiddleFunc{},
    );
    try nimbus.addRoute("/users/:id", "PATCH", routes.updateUser, &[_]MiddleFunc{});
    try nimbus.addRoute("/articles", "POST", articleroutes.createArticle, &[_]MiddleFunc{});
    try nimbus.addRoute("/signup", "POST", authroutes.signup, &[_]MiddleFunc{});
    try nimbus.addRoute("/pingnimbus", "POST", routes.pingNimbus, &[_]MiddleFunc{});
    try nimbus.addRoute("/dllpush", "POST", routes.dllNimbus, &[_]MiddleFunc{});
    try nimbus.addRoute("/ping", "POST", routes.ping, &[_]MiddleFunc{authroutes.createCacheSession});
    try nimbus.addRoute("/set", "POST", routes.set, &[_]MiddleFunc{});
    try nimbus.addRoute("/dllrange", "POST", routes.dllRangeNimbus, &[_]MiddleFunc{});
    try nimbus.addRoute("/createDB", "POST", articleroutes.createDB, &[_]MiddleFunc{});
    // try nimbus.addRoute("/users/:name/:id", "GET", routes.getUser);
    try nimbus.listen();
}

pub fn createBackendServer_two(port: u16) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    var allocator = arena.allocator();
    const server_addr = "127.0.0.1";
    const server_port = port;
    const config = Nimbus.Config{
        .server_addr = server_addr,
        .server_port = server_port,
        .sticky_server = false,
    };

    try init(allocator);
    var nimbus: Nimbus = undefined;
    try nimbus.new(config, &allocator);
    defer nimbus.deinit();

    try nimbus.addRoute(
        "/users/:id",
        "GET",
        routes.getUserById,
        &[_]MiddleFunc{mdauthroutes.verifyAuth},
    );
    try nimbus.addRoute(
        "/articles/:id",
        "GET",
        articleroutes.getArticleById,
        &[_]MiddleFunc{},
    );
    try nimbus.addRoute("/users/:id", "PATCH", routes.updateUser, &[_]MiddleFunc{});
    try nimbus.addRoute("/articles", "POST", articleroutes.createArticle, &[_]MiddleFunc{});
    try nimbus.addRoute("/signup", "POST", authroutes.signup, &[_]MiddleFunc{});
    try nimbus.addRoute("/pingnimbus", "POST", routes.pingNimbus, &[_]MiddleFunc{});
    try nimbus.addRoute("/dllpush", "POST", routes.dllNimbus_two, &[_]MiddleFunc{});
    try nimbus.addRoute("/ping", "POST", routes.ping, &[_]MiddleFunc{});
    // try nimbus.addRoute("/users/:name/:id", "GET", routes.getUser);
    try nimbus.listen();
}

pub fn main() !void {
    try initCaches();
    var thread1 = try std.Thread.spawn(.{}, createBackendServer_one, .{8081});
    // var thread2 = try std.Thread.spawn(.{}, createBackendServer_two, .{8082});
    thread1.join();
    // thread2.join();
}
