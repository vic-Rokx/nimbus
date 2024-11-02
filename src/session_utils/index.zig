const std = @import("std");
const helpers = @import("../helpers/index.zig");

pub fn generateSessionToken(buf: []u8) void {
    helpers.newV4().to_string(buf);
}
