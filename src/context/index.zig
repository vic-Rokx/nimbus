const std = @import("std");
const net = std.net;
const mem = std.mem;
const Parsed = std.json.Parsed;
const helpers = @import("../helpers/index.zig");
const Cookie = @import("../core/Cookie.zig");
const TLSStruct = @import("../tls/tlsserver.zig");
const TLSServer = TLSStruct.TlsServer;
const print = std.debug.print;

pub const json_type = []const u8;

pub const CtxWriter = struct {
    pub fn tlsWrite(ssl: TLSStruct.SSL, resp: []const u8) void {
        TLSStruct.tlsWrite(ssl, resp);
    }
    pub fn httpWrite(conn: net.Server.Connection, resp: []const u8) !void {
        _ = try conn.stream.write(resp);
    }
};

pub const Self = @This();
arena: std.mem.Allocator,
params: std.StringHashMap([]const u8), // Array of key-value pairs for URL parameters
query_params: std.StringHashMap([]const u8), // Array of key-value pairs for query parameters
form_params: std.StringHashMap([]const u8), // Array of key-value pairs for form data
method: []const u8,
route: []const u8,
headers: std.StringHashMap([]const u8),
json_payload: []const u8,
payload: []const u8,
content_type: helpers.ContentType,
conn: ?net.Server.Connection,
ssl: ?TLSStruct.SSL,
cookies: std.StringHashMap(Cookie),
cookie: ?Cookie,
setValues: std.StringHashMap([]const u8),
sticky_session: ?[]const u8,

pub fn init(
    arena: *mem.Allocator,
    method: []const u8,
    route: []const u8,
    conn: ?net.Server.Connection,
    ssl: ?TLSStruct.SSL,
    content_type: helpers.ContentType,
) !Self {
    return Self{
        .arena = arena.*,
        .method = method,
        .route = route,
        .params = std.StringHashMap([]const u8).init(arena.*),
        .query_params = std.StringHashMap([]const u8).init(arena.*),
        .form_params = std.StringHashMap([]const u8).init(arena.*),
        .headers = std.StringHashMap([]const u8).init(arena.*),
        .json_payload = undefined,
        .payload = undefined,
        .content_type = content_type,
        .conn = conn,
        .ssl = ssl,
        .cookies = std.StringHashMap(Cookie).init(arena.*),
        .cookie = null,
        .setValues = std.StringHashMap([]const u8).init(arena.*),
        .sticky_session = null,
    };
}

pub fn deinit(self: *Self) !void {
    // Free the dynamically allocated memory for all hashmaps

    // Free params
    var it = self.params.iterator();
    while (it.next()) |entry| {
        self.arena.destroy(entry.value_ptr);
    }
    self.params.deinit();

    // Free query_params
    it = self.query_params.iterator();
    while (it.next()) |entry| {
        self.arena.destroy(entry.value_ptr);
    }
    self.query_params.deinit();

    // Free form_params
    it = self.form_params.iterator();
    while (it.next()) |entry| {
        self.arena.destroy(entry.value_ptr);
    }
    self.form_params.deinit();

    // Free headers
    it = self.headers.iterator();
    while (it.next()) |entry| {
        self.arena.destroy(entry.value_ptr);
    }
    self.headers.deinit();

    // Free json_payload if it was dynamically allocated (assuming it may be heap-allocated)
    if (self.json_payload.len > 0) {
        self.arena.free(self.json_payload);
    }
}

pub fn addParam(self: *Self, key: []const u8, value: []const u8) !void {
    try self.params.put(key, value);
}

pub fn addFormParam(self: *Self, key: []const u8, value: []const u8) !void {
    try self.form_params.put(key, value);
}

fn generateCookieString(self: *Self) !std.RingBuffer {
    var cookies_itr = self.cookies.keyIterator();
    var builder: std.RingBuffer = try std.RingBuffer.init(self.arena, 1024);
    while (cookies_itr.next()) |key| {
        const cookie = self.cookies.get(key.*).?;
        // const value: []const u8 = try std.fmt.allocPrint(
        //     std.heap.c_arena,
        //     "${}\r\n{s}\r\n",
        //     .{ size, node.*.value },
        // );
        try builder.writeSlice("Set-Cookie: ");
        try builder.writeSlice(key.*);
        try builder.writeSlice("=");
        try builder.writeSlice(cookie.value);
        try builder.writeSlice("; ");
        try builder.writeSlice("HttpOnly; Secure; Path=/; Max-Age=3600\r\n");
    }

    return builder;
}

pub fn ERROR(self: *Self, status_code: u16, string: []const u8) !void {
    var builder = try self.generateCookieString();
    defer builder.deinit(self.arena);
    const len = builder.len();
    const generate_cookies_str = builder.data[0..len];
    if (self.cookies.count() > 0) {
        const stt = "HTTP/1.1 {d} NOT FOUND \r\n" ++
            "{s}" ++
            "Connection: close\r\n" ++
            "Content-Type: text/html; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";
        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{
                status_code,
                generate_cookies_str,
                string.len,
                string,
            },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    } else {
        const stt = "HTTP/1.1 {d} NOT FOUND \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: text/html; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";
        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{ status_code, string.len, string },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    }
}

pub fn STRING(self: *Self, string: []const u8) !void {
    var builder = try self.generateCookieString();
    defer builder.deinit(self.arena);
    const len = builder.len();
    const generate_cookies_str = builder.data[0..len];
    if (self.cookies.count() > 0) {
        const stt = "HTTP/1.1 200 Success \r\n" ++
            "{s}" ++
            "Connection: close\r\n" ++
            "Content-Type: text/html; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";
        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{
                generate_cookies_str,
                string.len,
                string,
            },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    } else {
        const stt = "HTTP/1.1 200 Success \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: text/html; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";
        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{ string.len, string },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    }
}

pub fn JSON(self: *Self, comptime T: type, data: T) !void {
    var string = std.ArrayList(u8).init(self.arena);
    defer string.deinit();
    // Here the writer writes in bytes
    try std.json.stringify(data, .{}, string.writer());
    var builder = try self.generateCookieString();
    defer builder.deinit(self.arena);
    const len = builder.len();
    const generate_cookies_str = builder.data[0..len];

    if (self.cookies.count() > 0) {
        const stt = "HTTP/1.1 200 Success \r\n" ++
            "{s}" ++
            "Connection: close\r\n" ++
            "Content-Type: application/json; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";

        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{
                generate_cookies_str,
                string.items.len,
                string.items,
            },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    } else {
        const stt = "HTTP/1.1 200 Success \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: application/json; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";

        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{ string.items.len, string.items },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    }
}

pub fn HTML(self: *Self, html: []const u8) !void {
    // Here the writer writes in bytes
    var builder = try self.generateCookieString();
    defer builder.deinit(self.arena);
    const len = builder.len();
    const generate_cookies_str = builder.data[0..len];

    if (self.cookies.count() > 0) {
        const stt = "HTTP/1.1 200 Success \r\n" ++
            "{s}" ++
            "Connection: close\r\n" ++
            "Content-Type: application/json; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";

        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{
                generate_cookies_str,
                html.len,
                html,
            },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    } else {
        const stt = "HTTP/1.1 200 Success \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: application/json; charset=utf8\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n" ++
            "{s}";

        const response = std.fmt.allocPrint(
            self.arena,
            stt,
            .{
                html.len,
                html,
            },
        ) catch unreachable;
        if (self.ssl != null) {
            CtxWriter.tlsWrite(self.ssl.?, response);
        } else {
            try CtxWriter.httpWrite(self.conn.?, response);
        }
        self.arena.free(response);
    }
}

pub fn SET(self: *Self, key: []const u8, comptime T: type, data: T) !void {
    // var buf: [1024]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buf);
    var json = std.ArrayList(u8).init(self.arena);
    defer json.deinit();
    try std.json.stringify(data, .{}, json.writer());
    self.setValues.put(key, json.items);
}

pub fn setCookie(self: *Self, cookie: Cookie) !void {
    self.cookie = cookie;
}

pub fn putCookie(self: *Self, cookie: Cookie) !void {
    try self.cookies.put(cookie.name, cookie);
}

pub fn getCookie(self: *Self, cookie_name: []const u8) ?Cookie {
    const cookie = self.cookies.get(cookie_name);
    return cookie;
}

pub fn param(self: *Self, key: []const u8) ![]const u8 {
    const value = self.params.get(key);
    if (value == null) {
        return error.NoKeyValuePair;
    }
    return value.?;
}

pub fn setJson(self: *Self, haystack: []const u8) !void {
    const payload_start = std.mem.indexOf(u8, haystack, "\r\n\r\n") orelse {
        std.debug.print("Failed to find payload start.\n", .{});
        return error.PostFailed;
    } + 4; // Skip the "\r\n\r\n"
    const json_payload = haystack[payload_start..];
    self.json_payload = json_payload;
}

pub fn setPayload(self: *Self, haystack: []const u8) !void {
    const payload_start = std.mem.indexOf(u8, haystack, "\r\n\r\n") orelse {
        std.debug.print("Failed to find payload start.\n", .{});
        return error.PostFailed;
    } + 4; // Skip the "\r\n\r\n"
    const payload = haystack[payload_start..];
    self.payload = payload;
}

fn decoder(self: *Self, encoded: []const u8) ![]const u8 {
    var decoded = std.ArrayList(u8).init(self.arena);
    defer decoded.deinit();

    var i: usize = 0;
    while (i < encoded.len) : (i += 1) {
        if (encoded[i] == '%') {
            // Ensure there's enough room for two hex characters
            if (i + 2 >= encoded.len) {
                return error.InvalidInput;
            }

            const hex = encoded[i + 1 .. i + 3];
            const decodedByte = try std.fmt.parseInt(u8, hex, 16);
            try decoded.append(decodedByte);
            i += 2; // Skip over the two hex characters
        } else if (encoded[i] == '+') {
            // Replace '+' with a space
            try decoded.append(' ');
        } else {
            try decoded.append(encoded[i]);
        }
    }

    return decoded.toOwnedSlice();
}

pub fn parseForm(self: *Self) !void {
    if (self.content_type != helpers.ContentType.Form) return error.Malformed;
    var header_itr = mem.tokenizeSequence(u8, self.payload, "\r\n");
    while (header_itr.next()) |line| {
        const form_key = mem.sliceTo(line, '=');
        print("\n{s}", .{form_key});
        const form_value = mem.trimLeft(u8, line[form_key.len + 1 ..], " ");
        const form_decoded_value = try self.decoder(form_value);
        print("\n{s}", .{form_decoded_value});
        try self.addFormParam(form_key, form_decoded_value);
    }
}

// TODO figure what the hell is wrong with struct fields set to []const u8,
// but then to store it it needs to a []u8 field and then to stringify the struct field needs to []const u8
/// This function takes the Struct Type and outputs the parsed json payload into the struct.
///
/// # Parameters:
/// - `Context`: *Context.
/// - `T`: StructType.
///
/// # Returns:
/// Struct.
///
/// # Example:
/// try ctx.bind(CredentialsReq)
/// # Returns:
/// CredentialsReq { name: "Vic", password: "password" }.
pub fn bind(self: *Self, comptime T: type) !T {
    const fields = @typeInfo(T).Struct.fields;
    var parsed = std.json.parseFromSlice(
        T,
        self.arena,
        self.json_payload,
        .{},
    ) catch return error.MalformedJson;
    defer parsed.deinit();

    // we need to parse the struct []const u8 into []u8 to store in the hashmap
    inline for (fields) |f| {
        if (f.type == []const u8) {
            const field_value = @field(parsed.value, f.name);
            @field(parsed.value, f.name) = try helpers.convertStringToSlice(field_value, std.heap.c_allocator);
        }
    }
    return parsed.value;
}
