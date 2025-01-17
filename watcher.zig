// zig-dev.zig
const std = @import("std");
const BufferedChan = @import("channel.zig").BufferedChan;
const Chan = @import("channel.zig").Chan;
const fs = std.fs;
const process = std.process;
const time = std.time;
const heap = std.heap;
const log = std.log;

const color = "\x1b[35m"; // ANSI escape code for red color
const background = "\x1b[36m"; // ANSI escape code for red color
const reset = "\x1b[0m"; // ANSI escape code to reset color
const bold = "\x1b[1m"; // ANSI escape code to reset color

pub const Config = struct {
    watch_paths: []const []const u8 = &.{"src"}, // Directories to watch
    build_command: []const []const u8 = &.{ "zig", "build" }, // Default build command
    make_command: []const []const u8 = &.{"make"}, // Default build command
    run_dev_command: []const []const u8 = &.{ "zig", "run", "src/main.zig" },
    run_command: []const []const u8 = &.{"zig-out/bin/app"}, // Default run command
    file_extensions: []const []const u8 = &.{ ".zig", ".html" }, // File extensions to watch
    exclude_dirs: []const []const u8 = &.{ "zig-cache", "zig-out" }, // Directories to ignore
    debounce_ms: u64 = 100,
};

const WatchContext = struct {
    allocator: std.mem.Allocator,
    config: Config,
    last_mod_times: std.StringHashMap(i128),
    child_process: ?std.process.Child = null,

    pub fn init(allocator: std.mem.Allocator, config: Config) !*WatchContext {
        const ctx = try allocator.create(WatchContext);
        ctx.* = .{
            .allocator = allocator,
            .config = config,
            .last_mod_times = std.StringHashMap(i128).init(allocator),
        };
        return ctx;
    }

    pub fn deinit(self: *WatchContext) void {
        self.last_mod_times.deinit();
        self.allocator.destroy(self);
    }

    fn shouldWatch(self: *WatchContext, path: []const u8) bool {
        // Check if path has watched extension
        for (self.config.file_extensions) |ext| {
            if (std.mem.endsWith(u8, path, ext)) {
                // Check if path is in excluded directory
                for (self.config.exclude_dirs) |excluded| {
                    if (std.mem.indexOf(u8, path, excluded) != null) {
                        return false;
                    }
                }
                return true;
            }
        }
        return false;
    }

    fn killCurrentProcess(self: *WatchContext) !void {
        if (self.child_process) |*child| {
            _ = try child.kill();
            _ = try child.wait();
            self.child_process = null;
        }
    }

    fn buildAndRun(self: *WatchContext) !void {
        // Kill the current process if running
        try self.killCurrentProcess();

        // Execute the run_dev_command (zig run)
        var child = std.process.Child.init(self.config.make_command, self.allocator);
        child.stderr_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        try child.spawn();
        // _ = try child.kill();

        // child = std.process.Child.init(self.config.run_command, self.allocator);
        // child.stderr_behavior = .Inherit;
        // child.stdout_behavior = .Inherit;
        // try child.spawn();

        self.child_process = child;
    }
};

fn watchFiles(self: *WatchContext, chan: *Chan(u8)) !void {
    log.info("Starting Zig development server...", .{});
    log.info("Watching directories: {any}", .{self.config.watch_paths});

    for (self.config.watch_paths) |watch_path| {
        var dir = try fs.cwd().openDir(watch_path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            const path = try std.fs.path.join(self.allocator, &.{ watch_path, entry.path });
            // defer self.allocator.free(path);

            if (!self.shouldWatch(path)) continue;
            const stat = try fs.cwd().statFile(path);
            const mod_time = stat.mtime;
            const stored_time = self.last_mod_times.get(path);
            if (stored_time == null or stored_time.? != mod_time) {
                try self.last_mod_times.put(path, mod_time);
            }
        }
    }

    while (true) {
        var changed = false;
        var changed_path: []const u8 = "";

        // Check all watch paths
        for (self.config.watch_paths) |watch_path| {
            var dir = try fs.cwd().openDir(watch_path, .{ .iterate = true });
            defer dir.close();

            var walker = try dir.walk(self.allocator);
            defer walker.deinit();

            while (try walker.next()) |entry| {
                const path = try std.fs.path.join(self.allocator, &.{ watch_path, entry.path });
                // defer self.allocator.free(path);

                if (!self.shouldWatch(path)) continue;
                const stat = try fs.cwd().statFile(path);
                const mod_time = stat.mtime;
                const stored_time = self.last_mod_times.get(path);
                if (stored_time == null or stored_time.? != mod_time) {
                    changed_path = path;
                    // std.debug.print("{s}\n", .{path});
                    try self.last_mod_times.put(path, mod_time);
                    changed = true;
                }
            }
        }

        if (changed) {
            std.debug.print("{s}{s}File changed: {s}...{s}\n", .{
                color,
                bold,
                changed_path,
                reset,
            });
            std.debug.print("\x1b[32m{s}Changes detected, rebuilding...{s}\n", .{
                bold,
                reset,
            });
            const val: u8 = 1;
            try chan.send(val);
        }

        // Sleep to prevent high CPU usage
        std.time.sleep(1_000_000_000);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = Config{};
    var ctx = try WatchContext.init(allocator, config);
    defer ctx.deinit();

    const T = Chan(u8);
    var chan = T.init(allocator);
    defer chan.deinit();

    const thread = struct {
        fn func(c: *T, self: *WatchContext) !void {
            try self.buildAndRun();
            while (true) {
                std.time.sleep(1_000_000_000);
                const val = c.recv() catch {
                    continue;
                };
                if (val == 1) {
                    try self.buildAndRun();
                }
            }
        }
    };

    const t = try std.Thread.spawn(.{}, thread.func, .{ &chan, ctx });
    defer t.join();

    std.time.sleep(1_000_000_000);

    var watcher_thread = try std.Thread.spawn(.{}, watchFiles, .{ ctx, &chan });
    defer watcher_thread.join();
}
