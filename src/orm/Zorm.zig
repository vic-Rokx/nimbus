const std = @import("std");
const net = std.net;
const print = std.debug.print;
const c = @cImport({
    @cInclude("libpq-fe.h");
});

pub const Self = @This();
conn: *c.PGconn,

pub fn init() !Self {
    return Self{};
}

pub fn open(conn_info: [:0]const u8) !Self {
    const conn = c.PQconnectdb(conn_info);
    if (c.PQstatus(conn) != c.CONNECTION_OK) {
        print("Connect failed, err: {s}\n", .{c.PQerrorMessage(conn)});
        return error.connect;
    }
    return Self{ .conn = conn.? };
}
pub fn createTable(_: Self) !void {}

pub fn insertTable(self: Self) !void {
    // 1. create two prepared statements.
    {
        // There is no `get_last_insert_rowid` in libpq, so we use RETURNING id to get the last insert id.
        const res = c.PQprepare(
            self.conn,
            "insert_cat_colors",
            "INSERT INTO cat_colors (name) VALUES ($1) returning id",
            1, // nParams, number of parameters supplied
            // Specifies, by OID, the data types to be assigned to the parameter symbols.
            // When null, the server infers a data type for the parameter symbol in the same way it would do for an untyped literal string.
            null, // paramTypes.
        );
        defer c.PQclear(res);
        if (c.PQresultStatus(res) != c.PGRES_COMMAND_OK) {
            print("prepare insert cat_colors failed, err: {s}\n", .{c.PQerrorMessage(self.conn)});
            return error.prepare;
        }
    }
    {
        const res = c.PQprepare(self.conn, "insert_cats", "INSERT INTO cats (name, color_id) VALUES ($1, $2)", 2, null);
        defer c.PQclear(res);
        if (c.PQresultStatus(res) != c.PGRES_COMMAND_OK) {
            print("prepare insert cats failed, err: {s}\n", .{c.PQerrorMessage(self.conn)});
            return error.prepare;
        }
    }
    const cat_colors = .{
        .{
            "Blue", .{
                "Tigger",
                "Sammy",
            },
        },
        .{
            "Black", .{
                "Oreo",
                "Biscuit",
            },
        },
    };

    // 2. Use prepared statements to insert data.
    inline for (cat_colors) |row| {
        const color = row.@"0";
        const cat_names = row.@"1";
        const color_id = blk: {
            const res = c.PQexecPrepared(
                self.conn,
                "insert_cat_colors",
                1, // nParams
                &[_][*c]const u8{color}, // paramValues
                &[_]c_int{color.len}, // paramLengths
                &[_]c_int{0}, // paramFormats
                0, // resultFormat
            );
            defer c.PQclear(res);

            // Since this insert has returns, so we check res with PGRES_TUPLES_OK
            if (c.PQresultStatus(res) != c.PGRES_TUPLES_OK) {
                print("exec insert cat_colors failed, err: {s}\n", .{c.PQresultErrorMessage(res)});
                return error.InsertCatColors;
            }
            break :blk std.mem.span(c.PQgetvalue(res, 0, 0));
        };
        inline for (cat_names) |name| {
            const res = c.PQexecPrepared(
                self.conn,
                "insert_cats",
                2, // nParams
                &[_][*c]const u8{ name, color_id }, // paramValues
                &[_]c_int{ name.len, @intCast(color_id.len) }, // paramLengths
                &[_]c_int{ 0, 0 }, // paramFormats
                0, // resultFormat, 0 means text, 1 means binary.
            );
            defer c.PQclear(res);

            // This insert has no returns, so we check res with PGRES_COMMAND_OK
            if (c.PQresultStatus(res) != c.PGRES_COMMAND_OK) {
                print("exec insert cats failed, err: {s}\n", .{c.PQresultErrorMessage(res)});
                return error.InsertCats;
            }
        }
    }
}
