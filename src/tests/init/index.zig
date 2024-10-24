const NimbusClient = @import("../../client/index.zig");

pub var cache_client_one: NimbusClient = undefined; // Nullable to track initialization status.
pub var cache_client_two: NimbusClient = undefined; // Nullable to track initialization status.

pub fn init() !void {
    // Initialize NimbusClient at runtime.
    const user_cache = try NimbusClient.createClient(6379);
    cache_client_one = user_cache;
    const dll_cache = try NimbusClient.createClient(6380);
    cache_client_two = dll_cache;
}
