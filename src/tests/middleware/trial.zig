const std = @import("std");

const Middleware = struct {
    process: fn (_: *const Middleware, data: i32, next: fn (i32) void) void,
};

fn exampleMiddleware1(_: *const Middleware, data: i32, next: fn (i32) void) void {
    const new_data = data + 1;
    std.debug.print("Middleware 1: Data = {}\n", .{new_data});
    next(new_data);
}

fn exampleMiddleware2(_: *const Middleware, data: i32, next: fn (i32) void) void {
    const new_data = data * 2;
    std.debug.print("Middleware 2: Data = {}\n", .{new_data});
    next(new_data);
}

fn finalFunction(data: i32) void {
    std.debug.print("Final Function: Data = {}\n", .{data});
}

fn executeMiddlewares(middlewares: []const Middleware, data: i32) void {
    // inline for (middlewares) |_| {
    //     std.debug.print("{}", .{data});
    // }
    var current: usize = 0;

    const Next = struct {
        const Self = @This();
        current: *usize,
        data: i32,
        pub fn init(next_current: *usize, next_data: i32) Self {
            return Self{
                .current = next_current,
                .data = next_data,
            };
        }
        pub fn call(self: Self, next_data: i32) void {
            if (self.current.* < middlewares.len) {
                inline for (middlewares) |middlew| {
                    if (self.current.* < middlewares.len) {
                        std.debug.print("{}", .{next_data});
                        const mw = middlew;
                        self.current.* += 1;
                        mw.process(&mw, self.data, call);
                    }
                }
                finalFunction(self.data);
            }
        }
    };
    const next = Next.init(&current, data);
    next.call(data);

    // var state = next{ .current = current };
    // state.call(data);
}

pub fn main() void {
    const middlewares = [_]Middleware{
        .{ .process = exampleMiddleware1 },
        .{ .process = exampleMiddleware2 },
    };

    executeMiddlewares(middlewares[0..], 10); // Slicing the array to pass it as a slice
}
