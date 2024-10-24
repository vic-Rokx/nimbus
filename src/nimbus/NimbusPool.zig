const std = @import("std");
const posix = std.posix;
const utils = @import("../utils/index.zig");
const Nimbus = @import("./index.zig");

const ClientError = error{
    HeaderMalformed,
    RequestNotSupported,
    ProtoNotSupported,
    Success,
    ValueNotFound,
    FailedToSet,
    IndexOutOfBounds,
    ConnectionRefused,
    ServerError,
};

const ReturnTypes = enum {
    Success,
};

const Conn = struct {
    fd: c_int,
};

const Self = @This();
cache_pool: []Nimbus,

pub fn init(target: *Self, cache_pool: []Nimbus) !void {
    target.* = .{
        .cache_pool = cache_pool,
    };
}

pub fn createNimbus(_: Self, port: u16) !Nimbus {
    var cache: Nimbus = undefined;
    cache = try Nimbus.createClient(port);
    return cache;
}

pub fn test_caches(self: Self) !void {
    for (self.cache_pool) |cache| {
        _ = try cache.ping();
    }
}
