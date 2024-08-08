const std = @import("std");
const assert = std.debug.assert;

pub const page_size = 4096;

const Self = @This();

const PageMeta = struct {
    const Flags = packed struct(u8) {
        taken: bool,
        last: bool,
        _padding: u6 = undefined,
    };

    flags: Flags,
};

alloc_start: usize,
alloc_end: usize,
pages: []PageMeta,

pub fn init(start: usize, end: usize) Self {
    // This is all the pages available.
    const page_count = (end - start) / page_size;
    assert(start + @sizeOf(PageMeta) * page_count < end);

    const pages_start: [*]PageMeta = @ptrFromInt(start);
    const pages = pages_start[0..page_count];
    for (pages) |*page| {
        page.flags = .{ .taken = false, .last = undefined };
    }

    // We used a certain amount of pages for metadata.
    const alloc_start = roundUp(@intFromPtr(pages_start + page_count));
    const alloc_end = roundDown(end);

    return .{
        .pages = pages,
        .alloc_start = alloc_start,
        .alloc_end = alloc_end,
    };
}
pub fn alloc(self: *Self, pages: usize) ![]u8 {
    assert(pages > 0);

    const page_count = (self.alloc_end - self.alloc_start) / page_size;
    if (page_count < pages) return error.OutOfMemory;

    for (0..page_count - (pages - 1)) |first_page_index| {
        const range_valid = blk: {
            for (0..pages) |i| {
                if (self.pages[first_page_index + i].flags.taken) {
                    break :blk false;
                }
            } else {
                break :blk true;
            }
        };
        if (!range_valid) continue;
        for (0..pages) |i| {
            self.pages[first_page_index + i].flags = .{
                .taken = true,
                .last = (i + 1 == pages),
            };
        }
        const ptr: [*]u8 = @ptrFromInt(self.alloc_start + first_page_index * page_size);
        return ptr[0 .. page_count * page_size];
    }

    return error.OutOfMemory;
}

pub fn free(self: *Self, mem: []const u8) void {
    const addr = @intFromPtr(mem.ptr);
    assert(addr % page_size == 0);
    assert(self.alloc_start <= addr and addr < self.alloc_end);

    const page_count = (self.alloc_end - self.alloc_start) / page_size;
    const first_page_index = (addr - self.alloc_start) / page_size;
    for (self.pages[first_page_index..page_count]) |*page| {
        assert(page.flags.taken);
        page.flags.taken = false;
        if (page.flags.last) break;
    } else {
        unreachable;
    }
}

pub fn printPageAllocations(self: *const Self, writer: std.io.AnyWriter) !void {
    try writer.print(
        \\
        \\PAGE ALLOCATION TABLE
        \\META: 0x{x} -> 0x{x}
        \\PHYS: 0x{x} -> 0x{x}
        \\~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        \\
    ,
        .{
            @intFromPtr(self.pages.ptr),
            @intFromPtr(self.pages.ptr + self.pages.len),
            self.alloc_start,
            self.alloc_end,
        },
    );

    const page_count = (self.alloc_end - self.alloc_start) / page_size;
    var allocations: usize = 0;
    var page_index: usize = 0;
    while (page_index < page_count) {
        var len: usize = 0;
        for (self.pages[page_index..page_count]) |page| {
            if (!page.flags.taken) break;
            len += 1;
            if (page.flags.last) break;
        } else {
            unreachable;
        }

        if (len == 0) {
            page_index += 1;
            continue;
        }
        const last_page = self.pages[page_index + len - 1];
        assert(last_page.flags.taken);
        assert(last_page.flags.last);

        allocations += len;
        try writer.print("0x{x} => 0x{x}: {:>3} page(s).\n", .{
            self.alloc_start + page_size * page_index,
            self.alloc_start + page_size * (page_index + len) - 1,
            len,
        });

        page_index += len;
    }

    if (allocations > 0) {
        try writer.writeAll(
            \\~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            \\
        );
    }
    try writer.print(
        \\Allocated: {d:>6} pages ({d:>10} bytes).
        \\Free     : {d:>6} pages ({d:>10} bytes).
        \\
    ,
        .{
            allocations,
            allocations * page_size,
            page_count - allocations,
            (page_count - allocations) * page_size,
        },
    );
}

fn roundDown(v: usize) usize {
    return v / page_size * page_size;
}

fn roundUp(v: usize) usize {
    return (v / page_size + 1) * page_size;
}
