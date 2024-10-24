const std = @import("std");
const Cookie = @import("../core/Cookie.zig");
const mem = std.mem;
const testing = std.testing;
const crypto = std.crypto;
const fmt = std.fmt;

const ServerError = error{
    HeaderMalformed,
    RequestNotSupported,
    ProtoNotSupported,
};

const CookieTypes = enum {
    // Authorization,
    Session,
};

const RequestTypes = enum {
    GET,
    POST,
    PATCH,
    PUT,
    DELETE,
};

const Header = enum {
    Host,
    @"User-Agent",
    Cookie,
};

const HeaderCookie = enum {
    Cookie,
};

const HTTPHeader = struct {
    request_line: []const u8,
    host: []const u8,
    user_agent: []const u8,
    cookie: []const u8,
    cookies: std.ArrayList([]const u8),
    method: []const u8,

    pub fn init() !HTTPHeader {
        return HTTPHeader{
            .request_line = undefined,
            .host = undefined,
            .user_agent = undefined,
            .cookie = undefined,
            .cookies = std.ArrayList([]const u8).init(std.heap.c_allocator),
            .method = undefined,
        };
    }

    pub fn print(self: HTTPHeader) !void {
        std.debug.print("Req: {s}\nUser: {s}\nHost: {s}\n", .{
            self.request_line,
            self.user_agent,
            self.host,
            self.method,
        });
    }
};

pub fn generateSessionId() ![]const u8 {
    // var rng = std.crypto.random;
    // var session_id: [16]u8 = undefined;
    // rng.bytes(&session_id);
    // return session_id;
    var uuid_buf: [36]u8 = undefined;
    newV4().to_string(&uuid_buf);

    const hash = try convertStringToSlice(&uuid_buf, std.heap.c_allocator);
    return hash;
}

pub fn parseSession(recv_data: []u8) ![]const u8 {
    const cookie = parseCookie(recv_data);
    if (cookie != null) {
        // std.debug.print("\n{s}", .{cookie.?});
        var cookie_itr = std.mem.splitSequence(u8, cookie.?, "=");
        while (cookie_itr.next()) |line| {
            const cookie_type = std.meta.stringToEnum(CookieTypes, line) orelse continue;
            switch (cookie_type) {
                // .Authorization => {
                //     return convertStringTo16Slice(cookie_itr.peek().?);
                // },
                .Session => {
                    return cookie_itr.peek().?;
                },
            }
            cookie_itr.next();
        }
    }
    return generateSessionId();
}

fn parseCookie(header: []const u8) ?[]const u8 {
    var header_itr = std.mem.tokenizeSequence(u8, header, "\r\n");
    while (header_itr.next()) |line| {
        const name_slice = std.mem.sliceTo(line, ':');
        const header_name = std.meta.stringToEnum(HeaderCookie, name_slice) orelse continue;
        const header_value = std.mem.trimLeft(u8, line[name_slice.len + 1 ..], " ");
        switch (header_name) {
            .Cookie => return header_value,
        }
    }

    return null;
}

fn convertStringTo16Slice(haystack: []const u8) [16]u8 {
    var result: [16]u8 = [_]u8{0} ** 16; // Initialize with zeroes.
    std.mem.copyForwards(u8, result[0..16], haystack[0..16]);
    return result;
}

pub fn parseMethod(request_line: []const u8) ![]const u8 {
    var path_iter = mem.tokenizeScalar(u8, request_line, ' ');
    const method = try matchMethod(&path_iter);
    return method;
}

pub fn parsePath(request_line: []const u8) ![]const u8 {
    var path_iter = mem.tokenizeScalar(u8, request_line, ' ');
    _ = path_iter.next().?;
    const path = path_iter.next().?;
    if (path.len <= 0) return error.NoPath;
    const proto = path_iter.next().?;
    if (!mem.eql(u8, proto, "HTTP/1.1")) return ServerError.ProtoNotSupported;
    return path;
}

pub fn parseHeader(header: []const u8) !HTTPHeader {
    var header_struct = try HTTPHeader.init();
    var header_itr = mem.tokenizeSequence(u8, header, "\r\n");
    header_struct.request_line = header_itr.next() orelse return ServerError.HeaderMalformed;

    // var cookies = std.ArrayList([]const u8).init(std.heap.c_allocator);
    while (header_itr.next()) |line| {
        const name_slice = mem.sliceTo(line, ':');
        if (name_slice.len == line.len) return ServerError.HeaderMalformed;
        const header_name = std.meta.stringToEnum(Header, name_slice) orelse continue;
        const header_value = mem.trimLeft(u8, line[name_slice.len + 1 ..], " ");
        switch (header_name) {
            .Host => header_struct.host = header_value,
            .@"User-Agent" => header_struct.user_agent = header_value,
            .Cookie => {
                var cookies_split = std.mem.splitSequence(u8, header_value, "; ");
                while (cookies_split.next()) |cookie_line| {
                    var cookie_split = std.mem.splitSequence(u8, cookie_line, "=");
                    while (cookie_split.next()) |cookie_name_or_value| {
                        try header_struct.cookies.append(cookie_name_or_value);
                    }
                }
                header_struct.cookie = header_value;
            },
        }
    }

    return header_struct;
}

pub fn matchMethod(iter: *mem.TokenIterator(u8, .scalar)) ![]const u8 {
    const method = iter.next().?;
    const method_enum = std.meta.stringToEnum(RequestTypes, method).?;
    switch (method_enum) {
        .GET => return method,
        .POST => return method,
        .PATCH => return method,
        .DELETE => return method,
        .PUT => return method,
        // else => return ServerError.RequestNotSupported,
    }
}

pub fn matchDataType(path: []const u8) ![]const u8 {
    var path_iter = mem.tokenizeSequence(u8, path, "/");
    const path_type = path_iter.next();
    if (path_type == null) return error.Null;
    return path_type.?;
}

pub fn http404() []const u8 {
    return "HTTP/1.1 404 NOT FOUND \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 9\r\n" ++
        "\r\n" ++
        "NOT FOUND";
}

pub fn http401() []const u8 {
    return "HTTP/1.1 401 NOT FOUND \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 18\r\n" ++
        "\r\n" ++
        "Connection refused";
}

pub fn http400() []const u8 {
    return "HTTP/1.1 401 NOT FOUND \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 21\r\n" ++
        "\r\n" ++
        "Internal Server Error";
}

pub fn http200() []const u8 {
    return "HTTP/1.1 200 Success \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 7\r\n" ++
        "\r\n" ++
        "SUCCESS";
}

pub fn http201(_: []const u8) ![]const u8 {
    const response = try std.fmt.allocPrint(
        std.heap.c_allocator,
        "HTTP/1.1 200 Success \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: text/html; charset=utf8\r\n" ++
            "Content-Length: 12\r\n" ++
            "\r\n" ++
            "Added User",
        .{},
    );
    return response;
    // return "HTTP/1.1 200 Success \r\n" ++
    //     "Connection: close\r\n" ++
    //     "Content-Type: text/html; charset=utf8\r\n" ++
    //     "Content-Length: 12\r\n" ++
    //     "\r\n" ++
    //     "Added a user";
}

pub fn httpJsonMalformed() []const u8 {
    return "HTTP/1.1 406 Malformed JSON keys not found \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 14\r\n" ++
        "\r\n" ++
        "MALFORMED JSON";
}

pub fn convertStringToSlice(haystack: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const mutable_slice = try allocator.dupe(u8, haystack);
    return mutable_slice;
}

pub fn jsonStringify(comptime T: type, data: T, _: usize) ![]u8 {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var string = std.ArrayList(u8).init(fba.allocator());
    try std.json.stringify(data, .{}, string.writer());
    std.debug.print("\n data: {s}\n", .{string.items});
    return string.items;
}

pub const Error = error{InvalidUUID};

pub const UUID = struct {
    bytes: [16]u8,

    pub fn init() UUID {
        var uuid = UUID{ .bytes = undefined };

        crypto.random.bytes(&uuid.bytes);
        // Version 4
        uuid.bytes[6] = (uuid.bytes[6] & 0x0f) | 0x40;
        // Variant 1
        uuid.bytes[8] = (uuid.bytes[8] & 0x3f) | 0x80;
        return uuid;
    }

    pub fn to_string(self: UUID, slice: []u8) void {
        var string: [36]u8 = format_uuid(self);
        std.mem.copyForwards(u8, slice, &string);
    }

    fn format_uuid(self: UUID) [36]u8 {
        var buf: [36]u8 = undefined;
        buf[8] = '-';
        buf[13] = '-';
        buf[18] = '-';
        buf[23] = '-';
        inline for (encoded_pos, 0..) |i, j| {
            buf[i + 0] = hex[self.bytes[j] >> 4];
            buf[i + 1] = hex[self.bytes[j] & 0x0f];
        }
        return buf;
    }

    // Indices in the UUID string representation for each byte.
    const encoded_pos = [16]u8{ 0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34 };

    // Hex
    const hex = "0123456789abcdef";

    // Hex to nibble mapping.
    const hex_to_nibble = [256]u8{
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    };

    pub fn format(
        self: UUID,
        comptime layout: []const u8,
        options: fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options; // currently unused

        if (layout.len != 0 and layout[0] != 's')
            @compileError("Unsupported format specifier for UUID type: '" ++ layout ++ "'.");

        const buf = format_uuid(self);
        try fmt.format(writer, "{s}", .{buf});
    }

    pub fn parse(buf: []const u8) Error!UUID {
        var uuid = UUID{ .bytes = undefined };

        if (buf.len != 36 or buf[8] != '-' or buf[13] != '-' or buf[18] != '-' or buf[23] != '-')
            return Error.InvalidUUID;

        inline for (encoded_pos, 0..) |i, j| {
            const hi = hex_to_nibble[buf[i + 0]];
            const lo = hex_to_nibble[buf[i + 1]];
            if (hi == 0xff or lo == 0xff) {
                return Error.InvalidUUID;
            }
            uuid.bytes[j] = hi << 4 | lo;
        }

        return uuid;
    }
};

// Zero UUID
pub const zero: UUID = .{ .bytes = .{0} ** 16 };

// Convenience function to return a new v4 UUID.
pub fn newV4() UUID {
    return UUID.init();
}
