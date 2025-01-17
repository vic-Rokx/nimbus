const std = @import("std");
const c = @cImport({
    @cInclude("openssl/ssl.h");
    @cInclude("openssl/err.h");
    @cInclude("tlsserver.h");
});

pub const SSL = *c.SSL;

pub const TlsServer = struct {
    port: u16,
    running: bool = false,

    pub fn init(port: u16) !TlsServer {
        return TlsServer{
            .port = port,
        };
    }

    pub fn start(self: *TlsServer) !void {
        if (self.running) return error.ServerAlreadyRunning;

        const result = c.start_tls_server(@intCast(self.port));
        if (result != 0) return error.ServerStartFailed;

        self.running = true;
        std.debug.print("Server started on port {}\n", .{self.port});
    }

    pub fn tlsAcceptConn(_: *TlsServer) ?*c.SSL {
        return c.accept_connection();
    }

    pub fn tlsRead(_: *TlsServer, ssl: *c.SSL, buffer: *[4096]u8) c_int {
        return c.SSL_read(ssl, buffer, buffer.len);
    }

    pub fn tlsShutdown(_: *TlsServer, ssl: *c.SSL) void {
        _ = c.SSL_shutdown(ssl);
    }

    pub fn tlsFree(_: *TlsServer, ssl: *c.SSL) void {
        _ = c.SSL_free(ssl);
    }

    pub fn stop(self: *TlsServer) void {
        if (self.running) {
            c.cleanup_server();
            self.running = false;
        }
    }
};

pub fn tlsWrite(ssl: *c.SSL, response: []const u8) void {
    _ = c.SSL_write(ssl, @ptrCast(response), @intCast(response.len));
}
