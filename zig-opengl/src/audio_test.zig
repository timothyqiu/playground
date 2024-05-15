const std = @import("std");
const c = @cImport(@cInclude("miniaudio.h"));

pub fn main() !void {
    var wave_index: usize = 0;

    var config = c.ma_device_config_init(c.ma_device_type_playback);
    config.playback.format = c.ma_format_f32;
    config.playback.channels = 2;
    config.sampleRate = 48000;
    config.dataCallback = dataCallback;
    config.pUserData = &wave_index;

    var device: c.ma_device = undefined;
    if (c.ma_device_init(null, &config, &device) != c.MA_SUCCESS) {
        std.log.err("Failed to initialize MiniAudio", .{});
        return error.MiniAudioInitFailed;
    }
    defer c.ma_device_uninit(&device);

    std.log.info("Device Name: {s}", .{device.playback.name});

    if (c.ma_device_start(&device) != c.MA_SUCCESS) {
        return error.AudioDeviceStartFailed;
    }

    while (true) {}
}

fn dataCallback(
    device_v: ?*anyopaque,
    output_v: ?*anyopaque,
    input: ?*const anyopaque,
    frame_count: c.ma_uint32,
) callconv(.C) void {
    _ = input;

    const device: *c.ma_device = @ptrCast(@alignCast(device_v.?));
    const wave_index: *usize = @ptrCast(@alignCast(device.pUserData));
    const output: [*]f32 = @ptrCast(@alignCast(output_v.?));
    const channels = device.playback.channels;

    for (0..frame_count) |frame_id| {
        var t: f32 = @floatFromInt(wave_index.* + frame_id); // current sample
        t /= @floatFromInt(device.sampleRate); // to current time (second)
        t *= std.math.tau; // one cycle per second
        t *= 440; // 440Hz sine wave

        const sample_id = frame_id * channels;
        for (output[sample_id .. sample_id + channels]) |*sample| {
            sample.* = @sin(t);
        }
    }

    wave_index.* += frame_count;
}
