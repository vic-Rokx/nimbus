const std = @import("std");
const Mutex = std.Thread.Mutex;
const debug = std.debug;
const testing = std.testing;
const rand = std.crypto.random;

pub fn Shard(comptime VT: type) type {
    return struct {
        lock: Mutex,
        map: std.StringHashMap(VT),

        pub fn init(allocator: std.mem.Allocator) !Shard(VT) {
            const map = std.StringHashMap(VT).init(allocator);
            return Shard(VT){
                .lock = .{},
                .map = map,
            };
        }

        pub fn deinit(self: *Shard(VT)) void {
            self.map.deinit();
        }
    };
}

pub fn djbHash(key: []const u8) u32 {
    var hash: u32 = 5381;
    for (key) |byte| {
        hash = ((hash << 5) +% hash) +% byte;
    }
    return hash;
}

pub fn ShardMap(comptime VT: type) type {
    return struct {
        shard_count: usize,
        shards: std.ArrayList(*Shard(VT)),

        pub fn init(allocator: std.mem.Allocator, size: usize) !ShardMap(VT) {
            var new_shards_arr = std.ArrayList(*Shard(VT)).init(allocator);

            for (size) |_| {
                // We need to dynamically allocate the new_shard
                const new_shard = try allocator.create(Shard(VT)); // Dynamically allocate
                // Then we initilize the shard
                new_shard.* = try Shard(VT).init(allocator); // Initialize
                try new_shards_arr.append(new_shard);
            }

            return ShardMap(VT){
                .shard_count = size,
                .shards = new_shards_arr,
            };
        }

        pub fn getShard(self: *ShardMap(VT), key: []const u8) !*Shard(VT) {
            const hash = djbHash(key);
            const index = hash % self.shard_count;
            return self.shards.items[index];
        }

        pub fn get(self: *ShardMap(VT), key: []const u8) !?VT {
            const shard = try self.getShard(key);
            shard.*.lock.lock();
            defer shard.*.lock.unlock();
            const value = shard.*.map.get(key);
            return value;
        }

        pub fn set(self: *ShardMap(VT), key: []const u8, value: VT) !void {
            const shard = try self.getShard(key);
            shard.*.lock.lock();
            defer shard.*.lock.unlock();
            try shard.*.map.put(key, value);
        }

        pub fn delete(self: *ShardMap(VT), key: []const u8) !void {
            const shard = try self.getShard(key);
            shard.*.lock.lock();
            defer shard.*.lock.unlock();
            try shard.*.map.remove(key);
        }

        pub fn deinit(self: *ShardMap(VT)) void {
            while (self.shards.items.len > 0) {
                const shard = self.shards.items[self.shards.items.len - 1];
                shard.*.deinit(); // Properly deinitialize the shard
                self.shards.allocator.destroy(shard); // Correctly deallocate the shard
                self.shards.items.len -= 1; // Manually decrease the length
            }
            self.shards.deinit(); // Deinitialize the ArrayList itself
        }
    };
}

pub fn setInThread(shard_map: *ShardMap(u32), key: []const u8, value: u32) !void {
    try shard_map.set(key, value);
    debug.print("setting {s}, value: {}\n", .{ key, value });
}
pub fn getInThread(shard_map: *ShardMap(u32), key: []const u8) !void {
    const value = try shard_map.get(key);
    debug.print("getting {s}, value: {}\n", .{ key, value });
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const shard_count: usize = 32;

    var shard_map = try ShardMap(u32).init(allocator, shard_count);
    defer shard_map.deinit();
    const keys = try allocator.alloc([]const u8, 5);
    defer allocator.free(keys);

    for (0..keys.len) |i| {
        // Allocate space for each key including null terminator
        var key_new = try allocator.alloc(u8, 5); // "keyX\0"

        // Generate the key string, ensuring space for null terminator
        const keyName = try std.fmt.bufPrint(key_new[0..5], "key{}0", .{i + 1});
        // Store the pointer in the keys array
        keys[i] = keyName;
    }

    for (keys) |key_name| {
        const v = rand.intRangeAtMost(u8, 0, 255);
        _ = try std.Thread.spawn(.{}, setInThread, .{ &shard_map, key_name, v });
    }

    for (keys) |key_name| {
        _ = try std.Thread.spawn(.{}, getInThread, .{ &shard_map, key_name });
    }

    for (keys) |key_slice| {
        allocator.free(key_slice[0..5]);
    }
}

// test "memmory leaks" {
//     const allocator = std.testing.allocator;

//     const shard_count: usize = 32;

//     var shard_map = try ShardMap(u32).init(allocator, shard_count);
//     defer shard_map.deinit();
//     const keys = try allocator.alloc([]const u8, 5);
//     defer allocator.free(keys);

//     for (0..keys.len) |i| {
//         // Allocate space for each key including null terminator
//         var key_new = try allocator.alloc(u8, 5); // "keyX\0"

//         // Generate the key string, ensuring space for null terminator
//         const keyName = try std.fmt.bufPrint(key_new[0..5], "key{}0", .{i + 1});
//         // Store the pointer in the keys array
//         keys[i] = keyName;
//     }

//     for (keys) |key_name| {
//         const v = rand.intRangeAtMost(u8, 0, 255);
//         _ = try std.Thread.spawn(.{}, setInThread, .{ &shard_map, key_name, v });
//     }

//     for (keys) |key_name| {
//         _ = try std.Thread.spawn(.{}, getInThread, .{ &shard_map, key_name });
//     }

//     for (keys) |key_slice| {
//         allocator.free(key_slice[0..5]);
//     }
// }
