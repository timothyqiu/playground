const std = @import("std");
const c = @import("c.zig");

pub const VideoFrame = struct {
    stride: usize,
    width: usize,
    height: usize,
    pts: f64,
    y: []const u8,
    u: []const u8,
    v: []const u8,
};

pub const AudioFrame = struct {
    const ChannelDataArray = std.BoundedArray([]const u8, 2);
    channel_data: ChannelDataArray,
};

pub const Frame = union(enum) {
    video: VideoFrame,
    audio: AudioFrame,
};

pub const VideoDecoder = struct {
    const Codec = struct {
        stream_index: usize,
        context: *c.AVCodecContext,
    };

    const CodecArray = std.BoundedArray(Codec, 2);

    fmt_ctx: *c.AVFormatContext,
    codecs: CodecArray,
    packet: *c.AVPacket,
    frame: *c.AVFrame,

    pub fn init(path: [:0]const u8) !VideoDecoder {
        var fmt_ctx = try makeFormatContext(path);
        errdefer c.avformat_close_input(@ptrCast(&fmt_ctx));

        var codecs = try makeCodecs(fmt_ctx);
        errdefer freeCodecs(&codecs);

        var packet = c.av_packet_alloc() orelse {
            return error.PacketAllocationFailed;
        };
        errdefer c.av_packet_free(&packet);

        var frame = c.av_frame_alloc() orelse {
            return error.FrameAllocationFailed;
        };
        errdefer c.av_frame_free(&frame);

        return .{
            .fmt_ctx = fmt_ctx,
            .codecs = codecs,
            .packet = packet,
            .frame = frame,
        };
    }

    pub fn deinit(self: *VideoDecoder) void {
        c.av_frame_free(@ptrCast(&self.frame));
        c.av_packet_free(@ptrCast(&self.packet));
        freeCodecs(&self.codecs);
        c.avformat_close_input(@ptrCast(&self.fmt_ctx));
    }

    pub fn next(self: *VideoDecoder) !?Frame {
        while (true) {
            switch (c.av_read_frame(self.fmt_ctx, self.packet)) {
                c.AVERROR_EOF => return null,
                else => |ret| if (ret < 0) {
                    return error.ReadFrameError;
                },
            }
            defer c.av_packet_unref(self.packet);

            const stream_index: usize = @intCast(self.packet.stream_index);
            const dec_ctx = self.getCodecContext(stream_index) orelse {
                continue;
            };

            switch (c.avcodec_send_packet(dec_ctx, self.packet)) {
                c.AVERROR_EOF => return null,
                c.AVERROR(c.EAGAIN) => continue,
                else => |ret| if (ret < 0) {
                    return error.SendPacketFailed;
                },
            }

            switch (c.avcodec_receive_frame(dec_ctx, self.frame)) {
                c.AVERROR_EOF => return null,
                c.AVERROR(c.EAGAIN) => continue,
                else => |ret| if (ret < 0) {
                    return error.ReceiveFrameFailed;
                },
            }

            switch (dec_ctx.codec.*.type) {
                c.AVMEDIA_TYPE_AUDIO => return try self.handleAudioFrame(),
                c.AVMEDIA_TYPE_VIDEO => return try self.handleVideoFrame(),
                else => unreachable,
            }
        }
    }

    fn handleVideoFrame(self: *VideoDecoder) !Frame {
        const frame = self.frame.*;
        const width: usize = @intCast(frame.width);
        const height: usize = @intCast(frame.height);
        const stride: usize = @intCast(frame.linesize[0]);

        if (frame.format != c.AV_PIX_FMT_YUV420P) {
            std.log.debug("Unexpected pixel format: {s}", .{c.av_get_pix_fmt_name(frame.format)});
            return error.UnexpectedPixelFormat;
        }
        if (frame.linesize[1] != @divExact(frame.linesize[0], 2) or frame.linesize[2] != @divExact(frame.linesize[0], 2)) {
            std.log.debug("Unexpected YUV stride: {any}", .{frame.linesize});
            return error.UnexpectedYUVStride;
        }
        // if (resolveColorSpaceYUV(self.frame) != c.AVCOL_SPC_BT709) {
        //     return error.UnexpectedColorSpace;
        // }

        const size = stride * height;
        const y = frame.data[0][0..size];
        const u = frame.data[1][0 .. size / 4];
        const v = frame.data[2][0 .. size / 4];

        var pts: f64 = @floatFromInt(frame.pts);
        pts *= c.av_q2d(self.fmt_ctx.streams[@intCast(self.packet.stream_index)].*.time_base);

        return .{ .video = .{
            .stride = stride,
            .width = width,
            .height = height,
            .pts = pts,
            .y = y,
            .u = u,
            .v = v,
        } };
    }

    fn handleAudioFrame(self: *VideoDecoder) !Frame {
        const frame = self.frame.*;
        const channel_count: usize = @intCast(frame.ch_layout.nb_channels);
        const sample_count: usize = @intCast(frame.nb_samples);
        const bytes: usize = sample_count * @sizeOf(f32); // @intCast(frame.linesize[0]);

        if (channel_count > 2) {
            std.log.warn("Unexpected audio channel count: {}", .{channel_count});
            return error.UnexpectedAudioChannelCount;
        }

        var channel_data = AudioFrame.ChannelDataArray.init(0) catch unreachable;
        for (0..channel_count) |i| {
            channel_data.append(frame.data[i][0..bytes]) catch unreachable;
        }

        return .{ .audio = .{
            .channel_data = channel_data,
        } };
    }

    fn makeFormatContext(path: [:0]const u8) !*c.AVFormatContext {
        var fmt_ctx: [*c]c.AVFormatContext = null;
        if (c.avformat_open_input(&fmt_ctx, path.ptr, null, null) < 0) {
            return error.OpenInputFileFailed;
        }
        return fmt_ctx;
    }

    fn makeCodecs(fmt_ctx: *c.AVFormatContext) !CodecArray {
        if (c.avformat_find_stream_info(fmt_ctx, null) < 0) {
            return error.FindStreamInfoFailed;
        }

        var codecs = CodecArray.init(0) catch unreachable;

        for ([_]c.AVMediaType{ c.AVMEDIA_TYPE_VIDEO, c.AVMEDIA_TYPE_AUDIO }) |media_type| {
            const index = c.av_find_best_stream(fmt_ctx, media_type, -1, -1, null, 0);
            if (index < 0) {
                std.log.warn("No stream for media type {}", .{media_type});
                continue;
            }
            const stream_index: usize = @intCast(index);
            const stream = fmt_ctx.streams[stream_index];
            const dec_ctx = makeDecoderContext(stream) catch |err| {
                std.log.warn("Failed to creat decoder for stream #{}: {}", .{ index, err });
                continue;
            };
            codecs.append(.{
                .stream_index = stream_index,
                .context = dec_ctx,
            }) catch unreachable;
        }

        if (codecs.len == 0) {
            return error.NoSuitableStreams;
        }
        return codecs;
    }

    fn makeDecoderContext(stream: *c.AVStream) !*c.AVCodecContext {
        const decoder = c.avcodec_find_decoder(stream.codecpar.*.codec_id) orelse {
            return error.DecoderNotFound;
        };

        var dec_ctx = c.avcodec_alloc_context3(decoder) orelse {
            return error.ContextAllocationFailed;
        };
        errdefer c.avcodec_free_context(&dec_ctx);

        if (c.avcodec_parameters_to_context(dec_ctx, stream.codecpar) < 0) {
            return error.CopyCodecParametersFailed;
        }
        if (c.avcodec_open2(dec_ctx, decoder, null) < 0) {
            return error.OpenCodecFailed;
        }
        return dec_ctx;
    }

    fn freeCodecs(codecs: *CodecArray) void {
        for (codecs.slice()) |*codec| {
            c.avcodec_free_context(@ptrCast(&codec.context));
        }
    }

    fn getCodecContext(self: VideoDecoder, stream_index: usize) ?*c.AVCodecContext {
        for (self.codecs.slice()) |codec| {
            if (codec.stream_index == stream_index) {
                return codec.context;
            }
        }
        return null;
    }

    fn resolveColorSpaceYUV(frame: *c.AVFrame) c.AVColorSpace {
        const YUV_SD_THRESHOLD = 576;
        if (frame.colorspace != c.AVCOL_SPC_UNSPECIFIED) {
            return frame.colorspace;
        }
        if (frame.height <= YUV_SD_THRESHOLD) {
            return c.AVCOL_SPC_BT470BG;
        }
        return c.AVCOL_SPC_BT709;
    }
};
