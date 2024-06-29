const std = @import("std");
const c = @cImport({
    @cInclude("zlib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Memory leaked!");
    const allocator = gpa.allocator();

    std.log.info("zlib version: {s}", .{c.zlibVersion()});

    const input =
        \\Hello, 世界！
        \\Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    ;

    const stdout = std.io.getStdOut().writer();
    try stdout.print(" Before: {d} bytes\n", .{input.len});

    const encoded = try deflate(allocator, input);
    defer allocator.free(encoded);
    try stdout.print("Encoded: {d} bytes\n", .{encoded.len});

    const decoded = try inflate(allocator, encoded);
    defer allocator.free(decoded);
    try stdout.print("Decoded: {d} bytes\n", .{decoded.len});

    try stdout.print("Same? {}\n", .{std.mem.eql(u8, input, decoded)});
}

fn deflate(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var res: c_int = undefined;

    var strm: c.z_stream = .{};
    res = c.deflateInit(&strm, c.Z_DEFAULT_COMPRESSION);
    if (res != c.Z_OK) {
        logZlibError(res, &strm);
        return error.DeflateInitFailed;
    }
    defer logZlibError(c.deflateEnd(&strm), null);

    var encoded = std.ArrayList(u8).init(allocator);
    defer encoded.deinit();

    strm.avail_in = @intCast(input.len);
    strm.next_in = @constCast(input.ptr);
    strm.avail_out = 0;

    while (true) {
        if (strm.avail_out == 0) {
            encoded.items.len = encoded.capacity - strm.avail_out;
            try encoded.ensureUnusedCapacity(input.len);
            strm.avail_out = @intCast(encoded.capacity - encoded.items.len);
            strm.next_out = encoded.allocatedSlice()[encoded.items.len..].ptr;
        }

        res = c.deflate(&strm, if (strm.avail_in > 0) c.Z_NO_FLUSH else c.Z_FINISH);
        switch (res) {
            c.Z_OK => continue,
            c.Z_STREAM_END => break,
            else => {
                logZlibError(res, &strm);
                break;
            },
        }
    }
    encoded.items.len = encoded.capacity - strm.avail_out;

    return allocator.dupe(u8, encoded.items);
}

fn inflate(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var res: c_int = undefined;

    var strm: c.z_stream = .{};
    res = c.inflateInit(&strm);
    if (res != c.Z_OK) {
        logZlibError(res, &strm);
        return error.InflateInitFailed;
    }
    defer logZlibError(c.inflateEnd(&strm), null);

    var decoded = std.ArrayList(u8).init(allocator);
    defer decoded.deinit();

    strm.avail_in = @intCast(input.len);
    strm.next_in = @constCast(input.ptr);
    strm.avail_out = 0;

    while (true) {
        if (strm.avail_out == 0) {
            decoded.items.len = decoded.capacity - strm.avail_out;
            try decoded.ensureUnusedCapacity(input.len * 2);
            strm.avail_out = @intCast(decoded.capacity - decoded.items.len);
            strm.next_out = decoded.allocatedSlice()[decoded.items.len..].ptr;
        }

        res = c.inflate(&strm, if (strm.avail_in > 0) c.Z_NO_FLUSH else c.Z_FINISH);
        switch (res) {
            c.Z_OK => continue,
            c.Z_STREAM_END => break,
            else => {
                logZlibError(res, &strm);
                break;
            },
        }
    }
    decoded.items.len = decoded.capacity - strm.avail_out;

    return allocator.dupe(u8, decoded.items);
}

fn logZlibError(code: c_int, strmp: ?*c.z_stream) void {
    if (code == c.Z_OK) return;
    if (strmp) |strm| {
        if (strm.msg) |msg| {
            std.log.err("zlib error {d}: {s}", .{ code, msg });
            return;
        }
    }
    std.log.err("zlib error {d}: {s}", .{ code, c.zError(code) });
}
