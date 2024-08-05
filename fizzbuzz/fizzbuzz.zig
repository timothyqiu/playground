const std = @import("std");

pub fn main() !void {
    const stdout_file = std.io.getStdOut();
    var bw = std.io.bufferedWriter(stdout_file.writer());
    const stdout = bw.writer();

    try fizzbuzz(stdout.any());
    try stdout.writeByte('\n');

    try bw.flush();
}

fn fizzbuzz(writer: std.io.AnyWriter) !void {
    for (1..101) |n| {
        if (n > 1) {
            try writer.writeAll(", ");
        }
        const fizz = n % 3 == 0;
        const buzz = n % 5 == 0;
        if (fizz) {
            try writer.writeAll("Fizz");
        }
        if (buzz) {
            try writer.writeAll("Buzz");
        }
        if (!fizz and !buzz) {
            try writer.print("{d}", .{n});
        }
    }
}

test {
    const expected = "1, 2, Fizz, 4, Buzz, Fizz, 7, 8, Fizz, Buzz, 11, Fizz, 13, 14, FizzBuzz, 16, 17, Fizz, 19, Buzz, Fizz, 22, 23, Fizz, Buzz, 26, Fizz, 28, 29, FizzBuzz, 31, 32, Fizz, 34, Buzz, Fizz, 37, 38, Fizz, Buzz, 41, Fizz, 43, 44, FizzBuzz, 46, 47, Fizz, 49, Buzz, Fizz, 52, 53, Fizz, Buzz, 56, Fizz, 58, 59, FizzBuzz, 61, 62, Fizz, 64, Buzz, Fizz, 67, 68, Fizz, Buzz, 71, Fizz, 73, 74, FizzBuzz, 76, 77, Fizz, 79, Buzz, Fizz, 82, 83, Fizz, Buzz, 86, Fizz, 88, 89, FizzBuzz, 91, 92, Fizz, 94, Buzz, Fizz, 97, 98, Fizz, Buzz";

    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    try fizzbuzz(buffer.writer().any());

    try std.testing.expectEqualStrings(expected, buffer.items);
}
