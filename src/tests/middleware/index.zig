const std = @import("std");
// const Context = @import("../../context/index.zig");
// Define a type for the handler function

// Define the Context struct (you can extend it as needed)
const Context = struct {
    // Add fields for context data
    user_id: u32,
};

const HandlerFunc = *const fn (*Context) void;
const MiddleFunc = *const fn (HandlerFunc, *Context) HandlerFunc;

// pub fn acceptCookie(ctx: *Context) anyerror!void {
//     var user = try ctx.bind(User);
//     user.id = try helpers.convertStringToSlice(user.id.?, std.heap.c_allocator);
//     try cache.user_db.put(user.id.?, user);
//     const cached_user = try cache.user_db.get(user.id.?);
//     _ = try ctx.JSON(User, cached_user);
// }

fn verifyAuth(next: HandlerFunc) HandlerFunc {
    // const next_fn = next;
    // const Func = struct {
    //     next: HandlerFunc = next_fn,
    //     fn call(ctx: *Context) void {
    //         next_fn(ctx);
    //     }
    // };
    return struct {
        fn call(ctx: *Context) void {
            // Call the next handler
            ctx.user_id += 20;
            next(ctx);
        }
    }.call;
}

const ValidateCall = struct {
    const Self = @This();
    next: HandlerFunc, // Store the next handler as a field

    fn init(next_fn: HandlerFunc) Self {
        return Self{
            .next = next_fn,
        };
    }

    fn call(self: *Self, ctx: *Context) HandlerFunc {
        // Modify the context
        ctx.user_id += 100;

        // Call the next handler
        return self.next(ctx); // Access 'next' from the struct
    }
};

fn validate(next: HandlerFunc, ctx: *Context) HandlerFunc {
    ctx.user_id += 300;
    return next;
}
const HandlerFuncC = *const fn (i32, i32) *const fn () i32;
fn createCounter(initial: i32, step: i32) *const fn () i32 {
    std.debug.print("{}, {}", .{ initial, step });

    const Contextt = struct {
        count: i32,
        increment: i32,

        pub fn increment(self: *@This()) i32 {
            self.count += self.increment;
            std.debug.print("{}", .{self.count});
            return self.count;
        }
    };
    const context = Contextt{ .count = initial, .increment = step };
    return struct {
        pub fn call() i32 {
            return context.increment;
        }
    }.call;
}

// Example handler function
fn myHandler(ctx: *Context) void {
    std.debug.print("Hello, user {}!\n", .{ctx.user_id});
}

const wrappedHandler = verifyAuth(myHandler);
const doubleWrappedHandler = validate(wrappedHandler);

fn addRoute(_: HandlerFunc, middlewares: []MiddleFunc) void {
    _ = middlewares;
    // parseMiddleWare(0, middlewares);
}

fn parseMiddleWare(func_num: usize, my_Handler: HandlerFunc, middleswares: []const MiddleFunc, ctx: *Context) void {
    if (func_num + 1 > middleswares.len) {
        myHandler(ctx);
    } else {
        const first_func = middleswares[func_num];
        const wrappedFunc = first_func(my_Handler, ctx);
        parseMiddleWare(func_num + 1, wrappedFunc, middleswares, ctx);
    }
}

const HandlerStruct = struct {
    handler: HandlerFuncC,
};

fn executeHandlers(handlers: []const MiddleFunc, _: *Context) void {
    for (handlers) |handler| {
        // handler(ctx);
        const fnh = handler.handler(1, 30);
        std.debug.print("{any}", .{fnh});
    }
}

pub fn main() !void {
    var ctx = Context{ .user_id = 1234 };

    // Create an ArrayList to store handlers dynamically
    // const allocator = std.heap.page_allocator;
    // const handler_list = [_]HandlerStruct{.{ .handler = createCounter }};
    const handler_list = [_]MiddleFunc{ validate, validate };
    parseMiddleWare(0, myHandler, handler_list[0..], &ctx);

    // const counter2 = createCounter(10, 5);

    // std.debug.print("Counter1: {}, {}, {}\n", .{ counter1(), counter1(), counter1() });
    // doubleWrappedHandler(&ctx);

    // Add handlers to the list
    // try handler_list.append(HandlerStruct{ .handler = createCounter });

    // Convert the ArrayList to a slice and pass it to another function
    // const handler_slice = handler_list.toOwnedSlice();
    // executeHandlers(handler_list[0..], &ctx);

    // Free the memory used by the ArrayList
}
