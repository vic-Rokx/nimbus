const std = @import("std");
const net = std.net;
const print = std.debug.print;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const peer = try net.Address.parseIp4("127.0.0.1", 8080);
    // Connect to peer
    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();
    print("Connecting to {}\n", .{peer});

    // Create the HTTP GET request
    const httpRequest = "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n";
    try stream.writer().writeAll(httpRequest);

    // Read the HTTP response
    const response = try stream.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(response);

    // Print the response
    std.debug.print("Received response:\n{any}\n", .{response});

    // Or just using `writer.writeAll`
    // try writer.writeAll("hello zig");
}
