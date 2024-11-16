const std = @import("std");
pub const ServerStats = @This();
requests_total: i64 = 0,
requests_active: usize = 0,
cache_hits: usize = 0,
cache_misses: usize = 0,
server_health: []const u8 = "Online",
uptime: f16 = 99.9,
errors: usize = 0,
requests_per_sec: i64 = 0,
start_time: i64 = 0,

pub fn init(self: *ServerStats) !void {
    self.start_time = std.time.milliTimestamp();
}

pub fn incrementReqCount(self: *ServerStats) void {
    self.requests_total += 10;
}
pub fn incrementActCount(self: *ServerStats) void {
    self.requests_active += 1;
}
pub fn decrementActCount(self: *ServerStats) void {
    self.requests_active -= 1;
}
pub fn incrementCacheHits(self: *ServerStats) void {
    self.cache_hits += 1;
}
pub fn incrementCacheMiss(self: *ServerStats) void {
    self.cache_misses += 1;
}

/// Calculate the number of requests per second
///
/// @param start_time - Timestamp when the server started (in milliseconds)
/// @param current_time - Current timestamp (in milliseconds)
/// @param total_requests - Total number of requests processed
/// @return Requests per second as a floating-point value
pub fn calculateRPS(self: *ServerStats) void {
    const current_time = std.time.milliTimestamp();
    const elapsed_ms = current_time - self.start_time;
    if (elapsed_ms == 0) return; // Avoid division by zero
    const elapsed_seconds = @divTrunc(elapsed_ms, 1000);
    if (elapsed_seconds == 0) return; // Avoid division by zero
    std.debug.print("Seconds passed {d}\n", .{elapsed_seconds});
    self.requests_per_sec = @divTrunc(self.requests_total, elapsed_seconds);
}
