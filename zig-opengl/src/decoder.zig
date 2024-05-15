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

pub const VideoDecoder = struct {
    fmt_ctx: *c.AVFormatContext,
    dec_ctx: *c.AVCodecContext,
    packet: *c.AVPacket,
    frame: *c.AVFrame,
    stream_index: usize,

    pub fn init(path: [:0]const u8) !VideoDecoder {
        var fmt_ctx = try makeFormatContext(path);
        errdefer c.avformat_close_input(@ptrCast(&fmt_ctx));

        const stream_index = try findVideoStream(fmt_ctx) orelse {
            return error.NoVideoStream;
        };
        const stream = fmt_ctx.streams[stream_index];

        var dec_ctx = try makeDecoderContext(stream);
        errdefer c.avcodec_free_context(@ptrCast(&dec_ctx));

        if (dec_ctx.pix_fmt != c.AV_PIX_FMT_YUV420P) {
            return error.PixelFormatNotYUV420P;
        }

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
            .dec_ctx = dec_ctx,
            .packet = packet,
            .frame = frame,
            .stream_index = stream_index,
        };
    }

    pub fn deinit(self: *VideoDecoder) void {
        c.av_frame_free(@ptrCast(&self.frame));
        c.av_packet_free(@ptrCast(&self.packet));
        c.avcodec_free_context(@ptrCast(&self.dec_ctx));
        c.avformat_close_input(@ptrCast(&self.fmt_ctx));
    }

    pub fn next(self: *VideoDecoder) !?VideoFrame {
        while (true) {
            switch (c.av_read_frame(self.fmt_ctx, self.packet)) {
                c.AVERROR_EOF => return null,
                else => |ret| if (ret < 0) {
                    return error.ReadFrameError;
                },
            }
            defer c.av_packet_unref(self.packet);

            if (self.packet.stream_index != self.stream_index) {
                continue;
            }

            switch (c.avcodec_send_packet(self.dec_ctx, self.packet)) {
                c.AVERROR_EOF => return null,
                c.AVERROR(c.EAGAIN) => continue,
                else => |ret| if (ret < 0) {
                    return error.SendPacketFailed;
                },
            }

            switch (c.avcodec_receive_frame(self.dec_ctx, self.frame)) {
                c.AVERROR_EOF => return null,
                c.AVERROR(c.EAGAIN) => continue,
                else => |ret| if (ret < 0) {
                    return error.ReceiveFrameFailed;
                },
            }

            break;
        }

        const frame = self.frame.*;
        const width: usize = @intCast(frame.width);
        const height: usize = @intCast(frame.height);
        const stride: usize = @intCast(frame.linesize[0]);

        if (frame.linesize[1] != @divExact(frame.linesize[0], 2) or frame.linesize[2] != @divExact(frame.linesize[0], 2)) {
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
        pts *= c.av_q2d(self.fmt_ctx.streams[self.stream_index].*.time_base);

        return .{
            .stride = stride,
            .width = width,
            .height = height,
            .pts = pts,
            .y = y,
            .u = u,
            .v = v,
        };
    }

    fn makeFormatContext(path: [:0]const u8) !*c.AVFormatContext {
        var fmt_ctx: [*c]c.AVFormatContext = null;
        if (c.avformat_open_input(&fmt_ctx, path.ptr, null, null) < 0) {
            return error.OpenInputFileFailed;
        }
        return fmt_ctx;
    }

    fn findVideoStream(fmt_ctx: *c.AVFormatContext) !?usize {
        if (c.avformat_find_stream_info(fmt_ctx, null) < 0) {
            return error.FindStreamInfoFailed;
        }
        const index = c.av_find_best_stream(fmt_ctx, c.AVMEDIA_TYPE_VIDEO, -1, -1, null, 0);
        if (index < 0) {
            return null;
        }
        return @intCast(index);
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
