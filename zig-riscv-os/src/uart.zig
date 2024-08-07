const std = @import("std");

pub const Uart = struct {
    base_address: [*]volatile u8,
    clock_frequency: usize,

    pub const ReadableRegister = enum(u3) {
        /// Receiver buffer.
        rbr = 0,
        /// Interrupt enable register.
        ier = 1,
        /// Interrupt identification register.
        iir = 2,
        /// Line control register.
        lcr = 3,
        /// Modem control register.
        mcr = 4,
        /// Line status register.
        lsr = 5,
        /// Modem status register.
        msr = 6,
        /// Scratch register.
        scr = 7,
    };
    pub const WritableRegister = enum(u3) {
        /// Transmitter holding buffer.
        thr = 0,
        /// Interrupt enable register.
        ier = 1,
        /// FIFO control register.
        fcr = 2,
        /// Line control register.
        lcr = 3,
        /// Modem control register.
        mcr = 4,
        /// Scratch register.
        scr = 7,
    };

    pub fn init(base_address: usize, clock_frequency: usize) Uart {
        const self: Uart = .{
            .base_address = @ptrFromInt(base_address),
            .clock_frequency = clock_frequency,
        };

        // Set word length to 8 bits.
        const lcr = 0b0000_0011;
        self.put(.lcr, lcr);

        // Enable FIFOs.
        self.put(.fcr, 0b0000_0001);

        // Enable receiver interrupts.
        self.put(.ier, 0b0000_0001);

        // Setting the Signaling Rate (BAUD).
        const baud = 38400;
        const divisor: u16 = @intCast(self.clock_frequency / (baud * 16));
        self.put(.lcr, lcr | 0b0100_0000);
        self.putDivisorLatch(divisor);
        self.put(.lcr, lcr);

        return self;
    }

    pub fn put(self: Uart, reg: WritableRegister, value: u8) void {
        self.base_address[@intFromEnum(reg)] = value;
    }

    pub fn get(self: Uart, reg: ReadableRegister) u8 {
        return self.base_address[@intFromEnum(reg)];
    }

    pub fn putDivisorLatch(self: Uart, value: u16) void {
        self.base_address[0] = @truncate(value); // DLL
        self.base_address[1] = @truncate(value >> 8); // DLH
    }

    pub fn getDivisorLatch(self: Uart) u16 {
        const dll = self.base_address[0];
        const dlh = self.base_address[1];
        return dlh << 8 | dll;
    }

    pub fn getData(self: Uart) ?u8 {
        if (self.get(.lsr) & 0b0000_0001 == 0) return null;
        return self.get(.rbr);
    }

    pub fn putData(self: Uart, value: u8) void {
        self.put(.thr, value);
    }

    pub fn writeAll(self: Uart, data: []const u8) void {
        for (data) |c| {
            self.putData(c);
        }
    }

    pub fn reader(self: *const Uart) UartReader {
        return .{ .context = self };
    }

    pub fn writer(self: *const Uart) UartWriter {
        return .{ .context = self };
    }
};

pub const UartWriteError = error{};
pub const UartWriter = std.io.GenericWriter(*const Uart, UartWriteError, uartWrite);

fn uartWrite(uart: *const Uart, bytes: []const u8) UartWriteError!usize {
    for (bytes) |b| {
        uart.putData(b);
    }
    return bytes.len;
}

pub const UartReadError = error{};
pub const UartReader = std.io.GenericReader(*const Uart, UartReadError, uartRead);

fn uartRead(uart: *const Uart, buffer: []u8) UartReadError!usize {
    var end: usize = 0;
    while (end < buffer.len) {
        if (uart.getData()) |b| {
            buffer[end] = b;
            end += 1;
        } else if (end > 0) {
            break;
        }
        // Returning 0 means EOF. Constant polling here.
    }
    return end;
}
