const std = @import("std");
// const helpers = @import("../helpers/index.zig");
const crypto = std.crypto;
const bcrypt = crypto.pwhash.bcrypt;

pub const Self = @This();
const params: bcrypt.Params = .{ .rounds_log = 10 };
const salt: [16]u8 = [_]u8{
    'X',
    'E',
    'l',
    'W',
    'z',
    '9',
    'W',
    'P',
    'w',
    'S',
    'L',
    'K',
    '3',
    'y',
    '0',
    'j',
};

pub fn convertStringToSlice(haystack: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const mutable_slice = try allocator.dupe(u8, haystack);
    return mutable_slice;
}

pub fn generatePassword(password: []const u8) ![]const u8 {
    // const hash_options: bcrypt.HashOptions = .{
    //     .allocator = std.heap.page_allocator,
    //     .params = params,
    //     .encoding = std.crypto.pwhash.Encoding.crypt,
    // };

    const saltHash = bcrypt.bcrypt(password, salt, params);

    const hash_options = bcrypt.HashOptions{
        .params = .{ .rounds_log = 5 },
        .encoding = .crypt,
        .silently_truncate_password = false,
    };
    var buffer: [bcrypt.hash_length * 2]u8 = undefined;
    const hash = bcrypt.strHash(
        password,
        hash_options,
        buffer[0..],
    ) catch |err| {
        return err;
    };
    //
    // const same = try comparePassword("password", hash[0..]);
    std.debug.print("\n{s}\n", .{hash});
    return saltHash[0..];
}

pub fn comparePassword(password: []const u8, hashedPassword: []u8) !bool {
    const saltHash = bcrypt.bcrypt(password, salt, params);
    std.debug.print("\n salt {any}\n", .{saltHash[0..]});
    std.debug.print("\n hash {any}\n", .{hashedPassword});
    return std.mem.eql(u8, saltHash[0..], hashedPassword);
    // const verify_options = bcrypt.VerifyOptions{};
    // bcrypt.strVerify(hashedPassword, password, verify_options) catch {
    //     return false;
    // };
    // return true;
}

pub fn testMultPass() !void {
    const hash = try generatePassword("password");
    std.debug.print("\ngen {any}\n", .{hash});
    // _ = try generatePassword("invalid password");
    const same = try comparePassword("password", hash[0..]);
    std.debug.print("\n{any}\n", .{same});
}

test "Insert" {
    try testMultPass();
}
