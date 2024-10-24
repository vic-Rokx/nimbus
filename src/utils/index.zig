const std = @import("std");
pub fn assert_cm(ok: bool, error_msg: []const u8) void {
    if (!ok) {
        const boldRed = "\x1b[1;31m"; // ANSI escape code for bold + red
        const reset = "\x1b[0m"; // Reset ANSI code to clear formatting
        std.debug.print("\n{s}Error{s}: ", .{ boldRed, reset });
        std.debug.print("{s}\n", .{error_msg});
        unreachable; // assertion failure
    }
}

pub fn error_print_str(error_msg: []const u8) void {
    const boldRed = "\x1b[1;31m"; // ANSI escape code for bold + red
    const reset = "\x1b[0m"; // Reset ANSI code to clear formatting
    std.debug.print("\n{s}Error{s}: ", .{ boldRed, reset });
    std.debug.print("{s}\n", .{error_msg});
}

pub fn generateSessionId() [16]u8 {
    var rng = std.crypto.random;
    var session_id: [16]u8 = undefined;
    rng.bytes(&session_id);
    return session_id;
}
