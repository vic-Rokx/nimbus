const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

pub fn main() !void {
    const ret = c.printf("hello from c world!\n");
    std.debug.print("C call return value: {d}\n", .{ret});

    const buf = c.malloc(10);
    if (buf == null) {
        std.debug.print("ERROR while allocating memory!\n", .{});
        return;
    }
    std.debug.print("buf address: {any}\n", .{buf});
    c.free(buf);
}
