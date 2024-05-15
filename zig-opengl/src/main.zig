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

    var gui = try Gui.init(alloc);
    defer gui.deinit();

    var decoder = try VideoDecoder.init(args[1]);
    defer decoder.deinit();
    std.log.info("video resolution is {d}x{d}", .{ decoder.dec_ctx.width, decoder.dec_ctx.height });
    std.log.info("video pixel format is {s}", .{c.av_get_pix_fmt_name(decoder.dec_ctx.pix_fmt)});

    var maybe_frame = try decoder.next();
    var timer = try std.time.Timer.start();
    var start_pts: f64 = 0;
    var paused = false;
    var fast_forward = false;

    while (!gui.shouldClose()) {
        while (gui.getNextAction()) |action| {
            switch (action) {
                .toggle_pause => {
                    paused = !paused;
                    if (!paused and maybe_frame != null) {
                        start_pts = maybe_frame.?.pts;
                        timer.reset();
                    }
                },

                .step => {
                    paused = true;
                    if (maybe_frame) |frame| {
                        gui.swapFrame(frame);
                        maybe_frame = try decoder.next();
                    }
                },

                .toggle_fast_forward => {
                    fast_forward = !fast_forward;
                    paused = false;
                    if (maybe_frame) |frame| {
                        start_pts = frame.pts;
                        timer.reset();
                    }
                },
            }
        }

        while (!paused and maybe_frame != null) {
            var now: f64 = @floatFromInt(timer.read());
            if (fast_forward) {
                now *= 16;
            }

            const frame = maybe_frame.?;
            if ((frame.pts - start_pts) * 1e9 <= now) {
                gui.swapFrame(frame);
                maybe_frame = try decoder.next();
                continue;
            }
            break;
        }

        gui.step();
    }
}
