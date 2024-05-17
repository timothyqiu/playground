const std = @import("std");
const c = @import("c.zig");
const decoder = @import("decoder.zig");
const Allocator = std.mem.Allocator;

pub const AudioPlayer = struct {
    const FrameQueue = std.fifo.LinearFifo(*FrameQueueItem, .{ .Static = 32 });

    allocator: Allocator,
    device: c.ma_device,
    frame_queue_mutex: std.Thread.Mutex,
    frame_queue: FrameQueue,

    pub fn create(allocator: Allocator, channels: usize, sample_rate: usize) !*AudioPlayer {
        const player: *AudioPlayer = try allocator.create(AudioPlayer);
        errdefer allocator.destroy(player);

        player.allocator = allocator;

        player.frame_queue_mutex = std.Thread.Mutex{};
        player.frame_queue = FrameQueue.init();
        errdefer player.frame_queue.deinit();

        var config = c.ma_device_config_init(c.ma_device_type_playback);
        config.playback.format = c.ma_format_f32;
        config.playback.channels = @intCast(channels);
        config.sampleRate = @intCast(sample_rate);
        config.dataCallback = dataCallback;
        config.pUserData = player;

        if (c.ma_device_init(null, &config, &player.device) != c.MA_SUCCESS) {
            std.log.err("Failed to initialize MiniAudio", .{});
            return error.MiniAudioInitFailed;
        }
        errdefer c.ma_device_uninit(&player.device);

        try player.start();

        return player;
    }

    pub fn destroy(player: *AudioPlayer) void {
        player.stop() catch {};
        c.ma_device_uninit(&player.device);
        while (player.frame_queue.readItem()) |item| {
            item.deinit();
        }
        player.frame_queue.deinit();
        player.allocator.destroy(player);
    }

    pub fn start(player: *AudioPlayer) !void {
        if (c.ma_device_start(&player.device) != c.MA_SUCCESS) {
            return error.AudioDeviceStartFailed;
        }
    }

    pub fn stop(player: *AudioPlayer) !void {
        if (c.ma_device_stop(&player.device) != c.MA_SUCCESS) {
            return error.AudioDeviceStopFailed;
        }
    }

    pub fn pushFrame(player: *AudioPlayer, frame: decoder.AudioFrame) !void {
        const item = try FrameQueueItem.create(player.allocator, frame);
        errdefer player.allocator.destroy(item);

        player.frame_queue_mutex.lock();
        defer player.frame_queue_mutex.unlock();
        try player.frame_queue.writeItem(item);
    }

    fn dataCallback(
        device_v: ?*anyopaque,
        output_v: ?*anyopaque,
        input: ?*const anyopaque,
        frame_count: c.ma_uint32,
    ) callconv(.C) void {
        _ = input;

        const device: *c.ma_device = @ptrCast(@alignCast(device_v));
        const player: *AudioPlayer = @ptrCast(@alignCast(device.pUserData));
        const output: [*]u8 = @ptrCast(output_v);
        const channels = device.playback.channels;
        const total: usize = frame_count * channels * @sizeOf(f32);

        player.frame_queue_mutex.lock();
        defer player.frame_queue_mutex.unlock();

        var written: usize = 0;
        while (written < total) {
            if (player.frame_queue.readableLength() == 0) {
                return;
            }

            const item = player.frame_queue.peekItem(0);
            if (item.next()) |sample| {
                @memcpy(output[written .. written + sample.len], sample);
                written += sample.len;
            } else {
                player.frame_queue.discard(1);
                item.deinit();
            }
        }
    }
};

const FrameQueueItem = struct {
    const ChannelDataArray = std.BoundedArray([]const u8, 2);

    allocator: Allocator,
    channel_data: ChannelDataArray,
    current_channel: usize,
    current_offset: usize,
    sample_size: usize,

    pub fn create(allocator: Allocator, frame: decoder.AudioFrame) !*FrameQueueItem {
        const item: *FrameQueueItem = try allocator.create(FrameQueueItem);
        errdefer allocator.destroy(item);

        item.allocator = allocator;
        item.channel_data = try FrameQueueItem.ChannelDataArray.init(0);
        item.current_channel = 0;
        item.current_offset = 0;
        item.sample_size = @sizeOf(f32);

        errdefer for (item.channel_data.constSlice()) |buffer| {
            allocator.free(buffer);
        };
        for (frame.channel_data.constSlice()) |raw| {
            const buffer = try allocator.alloc(u8, raw.len);
            @memcpy(buffer, raw);
            try item.channel_data.append(buffer);
        }

        return item;
    }

    pub fn deinit(self: *FrameQueueItem) void {
        for (self.channel_data.constSlice()) |buffer| {
            self.allocator.free(buffer);
        }
        self.allocator.destroy(self);
    }

    pub fn next(self: *FrameQueueItem) ?[]const u8 {
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
