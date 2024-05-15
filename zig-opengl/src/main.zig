const std = @import("std");
const c = @import("c.zig");
const Gui = @import("Gui.zig");
const VideoDecoder = @import("decoder.zig").VideoDecoder;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){
        .backing_allocator = std.heap.c_allocator,
    };
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    if (args.len < 2) {
        std.log.err("No video path given", .{});
        return error.InvalidArgs;
    }

    var gui = try Gui.init();
    defer gui.deinit();

    var decoder = try VideoDecoder.init(args[1]);
    defer decoder.deinit();
    std.log.info("video resolution is {d}x{d}", .{ decoder.dec_ctx.width, decoder.dec_ctx.height });
    std.log.info("video pixel format is {s}", .{c.av_get_pix_fmt_name(decoder.dec_ctx.pix_fmt)});

    var maybe_frame = try decoder.next();
    var timer = try std.time.Timer.start();
    while (!gui.shouldClose()) {
        if (maybe_frame) |frame| {
            if (frame.pts * 1e9 <= @as(f64, @floatFromInt(timer.read()))) {
                gui.swapFrame(frame);
                maybe_frame = try decoder.next();
                continue;
            }
        }
        gui.render();
    }
}
