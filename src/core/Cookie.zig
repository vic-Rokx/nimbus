const std = @import("std");

pub const Self = @This();
name: []const u8,
value: []const u8,
expires: i64,

pub fn init(name: []const u8, value: []const u8, expires: i64) Self {
    return Self{
        .name = name,
        .value = value,
        .expires = expires,
    };
}
