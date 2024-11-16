const std = @import("std");
const Context = @import("../context/index.zig");
const servers = @import("../stats/recorder.zig");

pub fn serverStatus(ctx: *Context) !void {
    // Simulate some response time variance
    var stats_html_buffer: [1024]u8 = undefined;
    const stats_html = try std.fmt.bufPrint(&stats_html_buffer,
        \\<h2>Server Metrics</h2>
        \\<div class="metric">
        \\<span class="metric-label">Server Health</span>
        \\<span class="metric-value">
        \\<span class="status status-healthy"></span>
        \\{s}
        \\</span>
        \\</div>
        \\<div class="metric">
        \\<span class="metric-label">Uptime</span>
        \\<span class="metric-value">{d}%</span>
        \\</div>
    , .{
        servers.server_stats.server_health,
        servers.server_stats.uptime,
    });

    _ = try ctx.STRING(stats_html);
}

pub fn requestMetrics(ctx: *Context) !void {
    servers.server_stats.calculateRPS();
    var stats_html_buffer: [1024]u8 = undefined;
    const stats_html = try std.fmt.bufPrint(&stats_html_buffer,
        \\<h2>Request Metrics</h2>
        \\<div class="metric">
        \\<span class="metric-label">Total Requests</span>
        \\<span class="metric-value">{d}</span>
        \\</div>
        \\<div class="metric">
        \\<span class="metric-label">Active Requests</span>
        \\<span class="metric-value">{d}</span>
        \\</div>
        \\<div class="metric">
        \\<span class="metric-label">Requests/sec</span>
        \\<span class="metric-value">{d}</span>
        \\</div>
    , .{
        servers.server_stats.requests_total,
        servers.server_stats.requests_active,
        servers.server_stats.requests_per_sec,
    });

    _ = try ctx.STRING(stats_html);
}

pub fn pageStats(ctx: *Context) !void {
    const cwd = std.fs.cwd();
    var file = cwd.openFile("./src/dashboard/index.html", .{}) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
        return;
    }; // Get file size
    const file_size = try file.getEndPos();

    // Read the entire file
    const contents = try file.readToEndAlloc(ctx.arena, file_size);
    defer ctx.arena.free(contents);

    _ = try ctx.STRING(contents);
}
