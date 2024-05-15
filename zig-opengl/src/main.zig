const std = @import("std");
const c = @import("c.zig");
const Gui = @import("Gui.zig");
const decoder = @import("decoder.zig");

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

    var video_decoder = try decoder.VideoDecoder.init(args[1]);
    defer video_decoder.deinit();

    for (video_decoder.codecs.slice(), 0..) |codec, i| {
        const dec_ctx: *c.AVCodecContext = codec.context;
        if (dec_ctx.codec.*.type == c.AVMEDIA_TYPE_VIDEO) {
            std.log.info("Stream #{d} video {d}x{d}; {s}", .{ i, dec_ctx.width, dec_ctx.height, c.av_get_pix_fmt_name(dec_ctx.pix_fmt) });
        } else {
            std.log.info("Stream #{d} audio {d}Hz; {d} channels; {s}", .{ i, dec_ctx.sample_rate, dec_ctx.ch_layout.nb_channels, c.av_get_sample_fmt_name(dec_ctx.sample_fmt) });
        }
    }

    var maybe_frame = try getNextVideoFrame(&video_decoder);
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
                        maybe_frame = try getNextVideoFrame(&video_decoder);
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
                maybe_frame = try getNextVideoFrame(&video_decoder);
                continue;
            }
            break;
        }

        gui.step();
    }
}

fn getNextVideoFrame(video_decoder: *decoder.VideoDecoder) !?decoder.VideoFrame {
    while (true) {
        const frame = try video_decoder.next();
        if (frame == null) {
            return null;
        }

        switch (frame.?) {
            .audio => {},
            .video => |vf| return vf,
        }
    }
}
