const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const ServerError = error{
    HeaderMalformed,
    RequestNotSupported,
    ProtoNotSupported,
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
};

const HTTPHeader = struct {
    request_line: []const u8,
    host: []const u8,
    user_agent: []const u8,
    method: []const u8,

    pub fn init() !HTTPHeader {
        return HTTPHeader{
            .request_line = undefined,
            .host = undefined,
            .user_agent = undefined,
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

    while (header_itr.next()) |line| {
        const name_slice = mem.sliceTo(line, ':');
        if (name_slice.len == line.len) return ServerError.HeaderMalformed;
        const header_name = std.meta.stringToEnum(Header, name_slice) orelse continue;
        const header_value = mem.trimLeft(u8, line[name_slice.len + 1 ..], " ");
        switch (header_name) {
            .Host => header_struct.host = header_value,
            .@"User-Agent" => header_struct.user_agent = header_value,
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

pub fn http200() []const u8 {
    return "HTTP/1.1 200 Succes \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 7\r\n" ++
        "\r\n" ++
        "SUCCESS";
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

pub fn matchRouteParam(_: []const u8, path: []const u8) !void {
    var path_iter = mem.tokenizeScalar(u8, path, ':');
    const upto_del = path_iter.next().?;
    const from_del = path_iter.next().?;

    std.debug.print("\n First part of the url path {s}", .{upto_del});
    std.debug.print("\n second part {s}\n", .{from_del});
}

test "Match route test" {
    try matchRouteParam("/users/Vic", "/users/:name");
}
