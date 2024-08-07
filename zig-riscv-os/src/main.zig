const std = @import("std");
const Uart = @import("uart.zig").Uart;

const uart: Uart = .{
    // https://github.com/qemu/qemu/blob/v9.0.2/hw/riscv/virt.c#L82
    .base_address = @ptrFromInt(0x1000_0000),
    // https://github.com/qemu/qemu/blob/v9.0.2/hw/riscv/virt.c#L919
    .clock_frequency = 3686400,
};

export fn zmain() noreturn {
    uart.prepare();

    // Handle possible errors locally.
    main() catch |err| {
        uart.writeAll("Unhandled error: ");
        uart.writeAll(@errorName(err));
    };

    while (true) {}
}

pub fn main() !void {
    const writer = uart.writer();
    const reader = uart.reader();

    uart.writeAll("Hello from Zig!\n");
    std.log.info("Press Ctrl-A and X to terminate QEMU", .{});

    const State = enum {
        start,
        escape,
        control_sequence,
    };
    var state: State = .start;

    while (true) {
        const c = reader.readByte() catch break;

        switch (state) {
            .start => switch (c) {
                // BS & DEL
                0x08, 0x7f => uart.writeAll("\x08 \x08"),

                // CR & LF
                '\r', '\n' => uart.putData('\n'),

                // ESC
                0x1b => state = .escape,

                else => uart.putData(c),
            },

            .escape => switch (c) {
                '[' => state = .control_sequence,
                else => state = .start,
            },

            .control_sequence => {
                switch (c) {
                    'A' => uart.writeAll("<UP>"),
                    'B' => uart.writeAll("<DOWN>"),
                    'C' => uart.writeAll("<RIGHT>"),
                    'D' => uart.writeAll("<LEFT>"),
                    else => {
                        if (std.ascii.isPrint(c)) {
                            try writer.print("<{c}>", .{c});
                        } else {
                            try writer.print("<0x{x:0>2}>", .{c});
                        }
                    },
                }
                if (0x40 <= c and c <= 0x7e) {
                    state = .start;
                }
            },
        }
    }
}

// `@panic()` uses `root.panic()` when available.
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    uart.writeAll("KERNEL PANIC: ");
    uart.writeAll(msg);
    while (true) {}
}

fn uartLogFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    var bw = std.io.bufferedWriter(uart.writer());
    const writer = bw.writer();

    writer.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
    bw.flush() catch return;
}

pub const std_options: std.Options = .{
    .logFn = uartLogFn,
};
