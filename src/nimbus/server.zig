const std = @import("std");
const Context = @import("../context/index.zig");
const servers = @import("../stats/recorder.zig");
const dashboard = @import("../dashboard/index.zig");
const Cookie = @import("../core/Cookie.zig");
const Radix = @import("../core/Radix.zig");
const helpers = @import("../helpers/index.zig");
const mem = std.mem;
const Parsed = std.json.Parsed;
const print = std.debug.print;
const net = std.net;

const Nimbus = @This();

pub const HandlerFunc = *const fn (*Context) anyerror!void;
pub const MiddleFunc = *const fn (HandlerFunc, *Context) anyerror!HandlerFunc;

pub const Config = struct {
    server_addr: []const u8,
    server_port: u16,
    sticky_server: bool,
};

routes: std.StringHashMap(Radix.Router),
arena: *mem.Allocator,
config: Config,

/// This function takes the Nimbus Config and a pointer to Nimbus to initialize.
///
/// # Parameters:
/// - `target`: *Nimbus.
/// - `config`: Nimbus.Config.
/// - `arena`: *std.mem.Allocator.
///
/// # Returns:
/// void.
pub fn new(target: *Nimbus, config: Config, arena: *mem.Allocator) !void {
    const routes_map = std.StringHashMap(Radix.Router).init(arena.*);
    target.* = .{
        .config = config,
        .arena = arena,
        .routes = routes_map,
    };
}

/// This function takes a pointer to this Nimbus instance.
/// Deinitializes the nimbus instance recursively calls routes deinit routes from radix tree
/// # Parameters:
/// - `target`: *Nimbus.
///
/// # Returns:
/// void.
pub fn deinit(nimbus: *Nimbus) void {
    var routes_it = nimbus.routes.valueIterator();
    while (routes_it.next()) |value| {
        try value.deinit();
    }

    nimbus.routes.deinit();
}

fn parseMiddleWare(func_num: usize, my_Handler: HandlerFunc, middleswares: []const MiddleFunc, ctx: *Context) !void {
    if (func_num + 1 > middleswares.len) {
        try my_Handler(ctx);
    } else {
        const first_func = middleswares[func_num];
        const wrappedFunc = try first_func(my_Handler, ctx);
        try parseMiddleWare(func_num + 1, wrappedFunc, middleswares, ctx);
    }
}

/// This function adds the route to the nimbus radix tree.
/// Deinitializes the nimbus instance recursively calls routes deinit routes from radix tree
/// # Parameters:
/// - `target`: *Nimbus.
/// - `path`: []const u8
/// - `method`: []const u8
/// - `handler`: HandlerFunc
/// - `middlewares`: []const MiddleFunc
///
/// # Returns:
/// !void.
pub fn addRoute(
    nimbus: *Nimbus,
    comptime path: []const u8,
    comptime method: []const u8,
    handler: HandlerFunc,
    middlewares: []const MiddleFunc,
) !void {
    var radix = nimbus.routes.get(method);

    if (radix == null) {
        radix = try Radix.Router.init(nimbus.arena.*);
    }
    try radix.?.addRoute(path, handler, middlewares);
    try nimbus.routes.put(method, radix.?);
    return;
}

fn callRoute(nimbus: *Nimbus, path: []const u8, method: []const u8, ctx: *Context) !void {
    var routesResult = nimbus.routes.get(method);
    if (routesResult == null) {
        return error.MethodNotSupported;
    }
    const entry = try routesResult.?.searchRoute(path);
    if (entry == null) {
        return error.MethodNotSupported;
    }
    if (entry.?.route_func == null) {
        return error.MethodNotSupported;
    }
    const entry_fn: *const fn (*Context) anyerror!void = @ptrCast(entry.?.route_func.?.handler_func);
    const middlewares = entry.?.route_func.?.middlewares;
    const param_args = entry.?.param_args;
    if (param_args.items.len > 0) {
        for (param_args.items) |param| {
            try ctx.addParam(param.param, param.value);
        }
    }

    try parseMiddleWare(0, entry_fn, middlewares, ctx);
}

fn parser(nimbus: Nimbus, comptime CacheType: type, haystack: []const u8) !Parsed(CacheType) {
    const payload_start = std.mem.indexOf(u8, haystack, "\r\n\r\n") orelse {
        std.debug.print("Failed to find payload start.\n", .{});
        return error.PostFailed;
    } + 4; // Skip the "\r\n\r\n"
    const json_payload = haystack[payload_start..];

    const parsed = std.json.parseFromSlice(
        CacheType,
        nimbus.arena.*,
        json_payload,
        .{},
    ) catch return error.MalformedJson;
    defer parsed.deinit();

    return parsed;
}

fn createContext(nimbus: *Nimbus, comptime T: type, data: T) !Context {
    const ctx = try Context.init(nimbus.arena, data);
    return ctx;
}

fn initDashboard(nimbus: *Nimbus) !void {
    print("Init dashboard\n", .{});
    try servers.server_stats.init();
    try nimbus.addRoute("/dashboard", "GET", dashboard.pageStats, &[_]MiddleFunc{});
    try nimbus.addRoute("/dashboard/server-status", "GET", dashboard.serverStatus, &[_]MiddleFunc{});
    try nimbus.addRoute("/dashboard/request-metrics", "GET", dashboard.requestMetrics, &[_]MiddleFunc{});
}

/// This function calls listen on the Nimbus instance.
///
/// # Returns:
/// !void.
pub fn listen(nimbus: *Nimbus) !void {
    // try servers.server_stats_1.init();
    // const color = "\x1b[38;5;57m";
    // const white = "\x1b[37m"; // White
    const red = "\x1b[31m"; // ANSI escape code for red color
    const background = "\x1b[36m"; // ANSI escape code for red color
    const reset = "\x1b[0m"; // ANSI escape code to reset color
    const bold = "\x1b[1m"; // ANSI escape code to reset color

    // const ascii_art =
    //     \\  ______    ______     __    __     ______   ______     ______     ______
    //     \\ /\__  _\  /\  ___\   /\ "-./  \   /\  == \ /\  ___\   /\  ___\   /\__  _\
    //     \\ \/_/\ \/  \ \  __\   \ \ \-./\ \  \ \  _-/ \ \  __\   \ \___  \  \/_/\ \/
    //     \\    \ \_\   \ \_____\  \ \_\ \ \_\  \ \_\    \ \_____\  \/\_____\    \ \_\
    //     \\     \/_/    \/_____/   \/_/  \/_/   \/_/     \/_____/   \/_____/     \/_/
    // ;
    // const ascii_art =
    //     \\                       __
    //     \\        __            /\ \
    //     \\   ___ /\_\    ___ ___\ \ \____  __  __    ____
    //     \\ /' _ `\/\ \ /' __` __`\ \ '__`\/\ \/\ \  /',__\
    //     \\ /\ \/\ \ \ \/\ \/\ \/\ \ \ \L\ \ \ \_\ \/\__, `\
    //     \\ \ \_\ \_\ \_\ \_\ \_\ \_\ \_,__/\ \____/\/\____/
    //     \\  \/_/\/_/\/_/\/_/\/_/\/_/\/___/  \/___/  \/___/
    // ;

    // const ascii_art =
    //     \\  __   __     __     __    __     ______     __  __     ______
    //     \\ /\ "-.\ \   /\ \   /\ "-./  \   /\  == \   /\ \/\ \   /\  ___\
    //     \\ \ \ \-.  \  \ \ \  \ \ \-./\ \  \ \  __<   \ \ \_\ \  \ \___  \
    //     \\  \ \_\\"\_\  \ \_\  \ \_\ \ \_\  \ \_____\  \ \_____\  \/\_____\
    //     \\   \/_/ \/_/   \/_/   \/_/  \/_/   \/_____/   \/_____/   \/_____/
    // ;
    // print("\n{s}{s}\n", .{ ascii_art, reset });

    const self_addr = try net.Address.resolveIp(nimbus.config.server_addr, nimbus.config.server_port);
    var server = try self_addr.listen(.{ .reuse_address = true });

    print("\n{s}{s}Running  {s}:{}{s}\n", .{ bold, background, nimbus.config.server_addr, nimbus.config.server_port, reset });
    try nimbus.initDashboard();

    while (server.accept()) |conn| {
        var recv_buf: [4096]u8 = undefined;
        var recv_total: usize = 0;
        while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
            if (recv_len == 0) break;
            recv_total += recv_len;
            if (mem.containsAtLeast(u8, recv_buf[0..recv_total], 1, "\r\n\r\n")) {
                break;
            }
        } else |read_err| {
            return read_err;
        }
        const recv_data = recv_buf[0..recv_total];
        if (recv_data.len == 0) {
            // Browsers (or firefox?) attempt to optimize for speed
            // by opening a connection to the server once a user highlights
            // a link, but doesn't start sending the request until it's
            // clicked. The request eventually times out so we just
            // go agane.
            std.debug.print("Got connection but no header!\n", .{});
            continue;
        }

        // var hash = try helpers.parseSession(recv_data);
        var header = try helpers.parseHeader(recv_data);
        const path = helpers.parsePath(header.request_line) catch |err| {
            if (err == error.MalformedJson) {
                _ = try conn.stream.writer().write(helpers.httpJsonMalformed());
                continue;
            } else if (err == error.Success) {
                _ = try conn.stream.writer().write(helpers.http200());
                continue;
            } else {
                return err;
            }
        };
        const method = try helpers.parseMethod(header.request_line);
        header.method = method;

        var ctx = try Context.init(nimbus.arena, method, path, conn);

        if (header.cookies.items.len > 0) {
            var cookie_count: usize = 0;
            while (cookie_count < header.cookies.items.len) {
                const expires = std.time.timestamp();
                const cookie = Cookie.init(
                    header.cookies.items[cookie_count],
                    header.cookies.items[cookie_count + 1],
                    expires,
                );
                try ctx.putCookie(cookie);
                cookie_count += 2;
            }
        }

        if (nimbus.config.sticky_server and ctx.getCookie("Session") == null) {
            const hash = try helpers.parseSession(recv_data);
            const expires = std.time.timestamp();
            const cookie = Cookie.init(
                "Session",
                hash,
                expires,
            );
            try ctx.putCookie(cookie);
            ctx.sticky_session = hash;
        }

        var path_itr = std.mem.tokenizeScalar(u8, path, '/');
        if (path_itr.peek() != null and !std.mem.eql(u8, path_itr.next().?, "dashboard")) {
            print("{s}{s}Accepted connection from:{s} {} {s} {s}\n", .{ red, bold, reset, conn.address, method, path });
            // servers.server_stats.incrementActCount();
            servers.server_stats.incrementReqCount();
        }

        try ctx.setJson(recv_data);
        const callRouteErr = nimbus.callRoute(path, method, &ctx);
        try ctx.deinit();

        if (callRouteErr == error.MethodNotSupported) {
            _ = try conn.stream.write(helpers.http404());
            conn.stream.close();
        } else if (callRouteErr == error.ConnectionRefused) {
            _ = try conn.stream.write(helpers.http401());
            conn.stream.close();
        }
        // else {
        //     _ = try conn.stream.write(helpers.http400());
        //     conn.stream.close();
        // }
    } else |err| {
        std.debug.print("error in accept: {}\n", .{err});
    }
}
