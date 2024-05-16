const std = @import("std");
const c = @import("c.zig");
const Gui = @import("Gui.zig");
const decoder = @import("decoder.zig");

pub fn main() !void {
    std.log.debug("Main thread {}", .{std.Thread.getCurrentId()});

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

    var audio_device_config: ?c.ma_device_config = null;

    for (video_decoder.codecs.slice(), 0..) |codec, i| {
        const dec_ctx: *c.AVCodecContext = codec.context;
        if (dec_ctx.codec.*.type == c.AVMEDIA_TYPE_VIDEO) {
            std.log.info("Stream #{d} video {d}x{d}; {s}", .{ i, dec_ctx.width, dec_ctx.height, c.av_get_pix_fmt_name(dec_ctx.pix_fmt) });
        } else {
            std.log.info("Stream #{d} audio {d}Hz; {d} channels; {s}", .{ i, dec_ctx.sample_rate, dec_ctx.ch_layout.nb_channels, c.av_get_sample_fmt_name(dec_ctx.sample_fmt) });

            if (dec_ctx.sample_fmt != c.AV_SAMPLE_FMT_FLTP) {
                std.log.warn("Unexpected audio sample format: {s}", .{c.av_get_sample_fmt_name(dec_ctx.sample_fmt)});
                continue;
            }

            var config = c.ma_device_config_init(c.ma_device_type_playback);
            config.playback.format = c.ma_format_f32;
            config.playback.channels = @intCast(dec_ctx.ch_layout.nb_channels);
            config.sampleRate = @intCast(dec_ctx.sample_rate);
            config.dataCallback = dataCallback;

            audio_device_config = config;
        }
    }

    if (audio_device_config == null) {
        std.log.info("No audio stream", .{});
        return;
    }

    var device: c.ma_device = undefined;
    if (c.ma_device_init(null, &audio_device_config.?, &device) != c.MA_SUCCESS) {
        std.log.err("Failed to initialize MiniAudio", .{});
        return error.MiniAudioInitFailed;
    }
    defer c.ma_device_uninit(&device);

    std.log.info("Audio device name: {s}", .{device.playback.name});

    var maybe_frame = try getNextVideoFrame(&video_decoder);
    var timer = try std.time.Timer.start();
    var start_pts: f64 = 0;
    var paused = false;

    if (c.ma_device_start(&device) != c.MA_SUCCESS) {
        return error.AudioDeviceStartFailed;
    }

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
            }
        }

        while (!paused and maybe_frame != null) {
            const now: f64 = @floatFromInt(timer.read());

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

const AudioFrameQueueItem = struct {
    const ChannelDataArray = std.BoundedArray([]const u8, 2);

    channel_data: ChannelDataArray,
    allocator: std.mem.Allocator,
    current_channel: usize,
    current_offset: usize,
    sample_size: usize,

    pub fn deinit(self: *AudioFrameQueueItem) void {
        for (self.channel_data.slice()) |data| {
            self.allocator.free(data);
        }
        self.allocator.destroy(self);
    }

    pub fn next(self: *AudioFrameQueueItem) ?[]const u8 {
        if (self.current_offset == self.channel_data.get(0).len) {
            return null;
        }
        defer {
            self.current_channel = (self.current_channel + 1) % self.channel_data.len;
            if (self.current_channel == 0) {
                self.current_offset += self.sample_size;
            }
        }
        return self.channel_data.get(self.current_channel)[self.current_offset..][0..self.sample_size];
    }
};

const AudioFrameQueue = std.fifo.LinearFifo(*AudioFrameQueueItem, .{ .Static = 32 });
var mutex = std.Thread.Mutex{};
var queue = AudioFrameQueue.init();

fn getNextVideoFrame(video_decoder: *decoder.VideoDecoder) !?decoder.VideoFrame {
    while (true) {
        const frame = try video_decoder.next();
        if (frame == null) {
            return null;
        }

        switch (frame.?) {
            .audio => |af| {
                var item = try std.heap.c_allocator.create(AudioFrameQueueItem);
                item.channel_data = AudioFrameQueueItem.ChannelDataArray.init(0) catch unreachable;
                item.allocator = std.heap.c_allocator;
                item.current_channel = 0;
                item.current_offset = 0;
                item.sample_size = @sizeOf(f32);

                for (af.channel_data.constSlice()) |raw| {
                    const buffer = try std.heap.c_allocator.alloc(u8, raw.len);
                    @memcpy(buffer, raw);
                    item.channel_data.append(buffer) catch unreachable;
                }

                mutex.lock();
                defer mutex.unlock();
                try queue.writeItem(item);
            },
            .video => |vf| return vf,
        }
    }
}

fn dataCallback(
    device_v: ?*anyopaque,
    output_v: ?*anyopaque,
    input: ?*const anyopaque,
    frame_count: c.ma_uint32,
) callconv(.C) void {
    _ = input;

    const device: *c.ma_device = @ptrCast(@alignCast(device_v));
    const output: [*]u8 = @ptrCast(output_v);
    const channels = device.playback.channels;
    const total: usize = frame_count * channels * @sizeOf(f32);

    mutex.lock();
    defer mutex.unlock();

    var written: usize = 0;
    while (written < total) {
        if (queue.readableLength() == 0) {
            return;
        }

        const item = queue.peekItem(0);
        if (item.next()) |sample| {
            @memcpy(output[written .. written + sample.len], sample);
            written += sample.len;
        } else {
            queue.discard(1);
            item.deinit();
        }
    }
}
