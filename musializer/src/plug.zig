const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const Plug = extern struct {
    music: c.Music,
};

const Complex32 = std.math.Complex(f32);
const N = 1 << 13;
var in_raw: [N]f32 = undefined;
var out_raw: [N]Complex32 = undefined;
var out_smooth = [_]f32{0} ** N;
var mutex = std.Thread.Mutex{};

pub export fn plug_init() ?*Plug {
    var plug = std.heap.c_allocator.create(Plug) catch return null;
    plug.music = std.mem.zeroes(c.Music);
    @memset(&in_raw, 0);
    return plug;
}

pub export fn plug_free(plug: *Plug) void {
    if (c.IsMusicReady(plug.music)) {
        c.UnloadMusicStream(plug.music);
    }
    std.heap.c_allocator.destroy(plug);
}

pub export fn plug_update(plug: *Plug) void {
    if (c.IsMusicReady(plug.music)) {
        c.UpdateMusicStream(plug.music);

        if (c.IsKeyPressed(c.KEY_SPACE)) {
            if (c.IsMusicStreamPlaying(plug.music)) {
                c.PauseMusicStream(plug.music);
            } else {
                c.ResumeMusicStream(plug.music);
            }
        }

        if (c.IsKeyPressed(c.KEY_Q)) {
            c.StopMusicStream(plug.music);
            c.PlayMusicStream(plug.music);
        }
    }

    if (c.IsFileDropped()) {
        const files = c.LoadDroppedFiles();
        defer c.UnloadDroppedFiles(files);

        if (files.count > 0) {
            if (c.IsMusicReady(plug.music)) {
                c.UnloadMusicStream(plug.music);
            }

            const path = files.paths[0];
            plug.music = c.LoadMusicStream(path);

            if (c.IsMusicReady(plug.music)) {
                c.SetMusicVolume(plug.music, 0.5);
                c.PlayMusicStream(plug.music);
                c.AttachAudioStreamProcessor(plug.music.stream, callback);
            } else {
                std.debug.print("Could not load music: {s}\n", .{path});
            }
        }
    }

    c.BeginDrawing();
    c.ClearBackground(c.BLACK);

    if (c.IsMusicReady(plug.music)) {
        // Apply the Hann Window on the input.
        var in_win: [N]f32 = undefined;
        {
            mutex.lock();
            defer mutex.unlock();

            for (in_raw, 0..) |sample, i| {
                const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(N));
                const hann = 0.5 - 0.5 * @cos(std.math.tau * t);
                in_win[i] = sample * hann;
            }
        }

        // FFT.
        fft(&in_win, &out_raw, 1, N);

        // Squash into the logarithmic scale.
        const step = 1.06;
        const lowf = 1.0;

        var max_amp: f32 = 1.0;
        var m: usize = 0;
        var out_log: [N]f32 = undefined;
        {
            var f: f32 = lowf;
            while (f < N / 2) : (f = @ceil(f * step)) {
                const next = @ceil(f * step);
                const a: f32 = blk: {
                    var result: f32 = 0;
                    var q: usize = @intFromFloat(f);
                    while (q < N / 2 and q < @as(usize, @intFromFloat(next))) : (q += 1) {
                        result = @max(result, amp(out_raw[q]));
                    }
                    break :blk result;
                };
                max_amp = @max(max_amp, a);
                out_log[m] = a;
                m += 1;
            }
        }

        // Normalize frequencies to 0..1 range.
        for (0..m) |i| {
            out_log[i] /= max_amp;
        }

        // Smooth.
        const speed = 8.0;
        for (0..m) |i| {
            const d = out_log[i] - out_smooth[i];
            const smoothed = out_smooth[i] + d * speed * c.GetFrameTime();

            if (out_log[i] > out_smooth[i]) {
                out_smooth[i] = @min(smoothed, out_log[i]);
            } else {
                out_smooth[i] = @max(smoothed, out_log[i]);
            }
        }

        const cell_width: f32 = @as(f32, @floatFromInt(c.GetRenderWidth())) / @as(f32, @floatFromInt(m));
        const window_height: f32 = @floatFromInt(c.GetRenderHeight());
        const full_height: f32 = @as(f32, @floatFromInt(c.GetRenderHeight())) * 2 / 3;

        for (out_smooth[0..m], 0..) |sample, i| {
            const height = full_height * sample;
            const start_pos = c.Vector2{
                .x = cell_width * (@as(f32, @floatFromInt(i)) + 0.5),
                .y = window_height - height,
            };
            const end_pos = c.Vector2{
                .x = start_pos.x,
                .y = window_height,
            };
            const thick = @max(1, cell_width / 2 * sample);
            const radius = cell_width * @sqrt(sample);
            const hue = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(m));
            const color = c.ColorFromHSV(hue * 360, 1, 1);
            c.DrawLineEx(start_pos, end_pos, thick, color);
            c.DrawCircleV(start_pos, radius, color);
        }
    } else {
        c.DrawText("Drop & Drop Music Here", 8, 8, 69, c.MAROON);
    }

    c.EndDrawing();
}

pub export fn plug_pre_reload(plug: *Plug) void {
    if (c.IsMusicReady(plug.music)) {
        c.DetachAudioStreamProcessor(plug.music.stream, callback);
    }
}

pub export fn plug_post_reload(plug: *Plug) void {
    @memset(&in_raw, 0);
    if (c.IsMusicReady(plug.music)) {
        c.AttachAudioStreamProcessor(plug.music.stream, callback);
    }
}

fn callback(buffer: ?*anyopaque, frames: c_uint) callconv(.C) void {
    const buffer_data: [*][2]f32 = @ptrCast(@alignCast(buffer.?));

    if (!mutex.tryLock()) {
        return;
    }
    defer mutex.unlock();

    if (frames < in_raw.len) {
        const keep = in_raw.len - frames;
        std.mem.copyForwards(f32, in_raw[0..keep], in_raw[frames..]);
        for (0..frames) |i| {
            in_raw[keep + i] = buffer_data[i][0];
        }
    } else {
        for (0..in_raw.len) |i| {
            in_raw[i] = buffer_data[frames - in_raw.len + i][0];
        }
    }
}

fn amp(freq: Complex32) f32 {
    // return std.math.complex.abs(freq);
    return @log(freq.re * freq.re + freq.im * freq.im);
    // return @max(@fabs(freq.re), @fabs(freq.im));
}

fn dft(in: []const f32, out: []Complex32) void {
    for (0..out.len) |f| {
        out[f] = .{ .re = 0, .im = 0 };
        for (0..in.len) |i| {
            const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(in.len));
            const eular = std.math.complex.exp(Complex32{
                .re = 0,
                .im = std.math.tau * @as(f32, @floatFromInt(f)) * t,
            });
            const v = Complex32{
                .re = in[i] * eular.re,
                .im = in[i] * eular.im,
            };
            out[f] = out[f].add(v);
        }
    }
}

fn fft(in: []const f32, out: []Complex32, stride: usize, n: usize) void {
    const half_n = @divTrunc(n, 2);

    if (n == 1) {
        out[0] = .{ .re = in[0], .im = 0 };
        return;
    }

    fft(in, out, stride * 2, half_n);
    fft(in[stride..], out[half_n..], stride * 2, half_n);

    for (0..half_n) |k| {
        const t: f32 = @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n));
        const v = std.math.complex.exp(Complex32{
            .re = 0,
            .im = std.math.tau * t,
        }).mul(out[k + half_n]);
        const e = out[k];
        out[k] = e.add(v);
        out[k + half_n] = e.sub(v);
    }
}
