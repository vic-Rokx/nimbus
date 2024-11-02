const std = @import("std");
const User = @import("../models.zig").User;
const Article = @import("../models.zig").Article;
const ShardMap = @import("../../cache/shard.zig").ShardMap;

pub fn Cache(comptime T: type) type {
    return struct {
        cache: ShardMap(T),

        pub fn init(allocator: std.mem.Allocator, size: usize) !Cache(T) {
            const cache = try ShardMap(T).init(allocator, size);
            return Cache(T){ .cache = cache };
        }
        pub fn get(self: *Cache(T), key: []const u8) !T {
            const result = try self.*.cache.get(key);
            if (result == null) {
                return error.NoValueInCache;
            }
            return result.?;
        }
        pub fn put(self: *Cache(T), key: []const u8, value: T) !void {
            try self.*.cache.set(key, value);
        }
        pub fn delete(_: *Cache(T)) !void {
            return error.CacheDeleteFailed;
        }
        pub fn deinit(self: *Cache(T)) void {
            self.cache.deinit();
        }
    };
}

pub var user_db: Cache(User) = undefined;
pub var user_hash_db: Cache([]const u8) = undefined;
pub var article_db: Cache(Article) = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    const shard_count: usize = 1;
    const user_cache = try Cache(User).init(
        allocator,
        shard_count,
    );

    user_db = user_cache;

    const user_hash_cache = try Cache([]const u8).init(
        allocator,
        shard_count,
    );

    user_hash_db = user_hash_cache;

    article_db = try Cache(Article).init(
        allocator,
        shard_count,
    );

    // const user = User{
    //     .id = null,
    //     .name = try helpers.convertStringToSlice("Alice", allocator),
    //     .age = 30,
    //     .height = 170,
    //     .weight = 60,
    //     .favoriteLanguage = try helpers.convertStringToSlice("Zig", allocator),
    // };

    // try user_db.put("Id", user);
}
