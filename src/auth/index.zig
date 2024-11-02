const std = @import("std");
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

const AuthError = error{
    VerificationInvalid,
};

pub const AuthEnum = enum {
    Success,
};

pub fn generatePassword(password: []const u8, arena: *std.mem.Allocator) ![]const u8 {
    const hash_options: bcrypt.HashOptions = .{
        .allocator = arena.*,
        .params = params,
        .encoding = std.crypto.pwhash.Encoding.crypt,
    };
    var buffer: [bcrypt.hash_length * 2]u8 = undefined;
    const hash = bcrypt.strHash(
        password,
        hash_options,
        buffer[0..],
    ) catch |err| {
        return err;
    };
    const s = try arena.*.alloc(u8, hash.len);
    std.mem.copyForwards(u8, s, hash);
    return s;
}

pub fn comparePassword(
    password: []const u8,
    hash: []const u8,
    arena: *std.mem.Allocator,
) AuthError!AuthEnum {
    bcrypt.strVerify(hash, password, bcrypt.VerifyOptions{
        .allocator = arena.*,
        .silently_truncate_password = false,
    }) catch {
        return AuthError.VerificationInvalid;
    };
    return AuthEnum.Success;
}

pub fn main() !void {
    var arena = std.heap.page_allocator;
    const password = "password";
    const hash = try generatePassword(password, &arena);
    _ = try comparePassword(password, hash, &arena);
}
