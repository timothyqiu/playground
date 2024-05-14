const std = @import("std");
const c = @cImport({
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavformat/avformat.h");
    @cInclude("libavutil/avutil.h");
    @cInclude("libavutil/pixdesc.h");
    @cInclude("stb_image.h");
    @cInclude("glad/glad.h");
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    if (args.len < 2) {
        std.log.err("No video path given", .{});
        return error.InvalidArgs;
    }

    const image = try getVideoFrame(alloc, args[1]);
    // const image = try Image.init(alloc, args[1]);
    defer image.deinit();

    if (c.glfwInit() == c.GLFW_FALSE) {
        std.log.err("Failed to initialize GLFW: {d}", .{c.glfwGetError(null)});
        return error.GlfwInitialization;
    }
    defer c.glfwTerminate();

    _ = c.glfwSetErrorCallback(errorCallback);

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    const window = c.glfwCreateWindow(640, 480, "My Title", null, null) orelse {
        std.log.err("Failed to create window: {d}", .{c.glfwGetError(null)});
        return error.CreateWindow;
    };
    defer c.glfwDestroyWindow(window);

    _ = c.glfwSetKeyCallback(window, keyCallback);

    c.glfwMakeContextCurrent(window);
    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == 0) {
        std.log.err("Failed to load OpenGL dec_ctx", .{});
        return error.LoadOpenGLContext;
    }

    var texture = makeTexture(image);
    defer c.glDeleteTextures(1, &texture);

    const shader_program = try createShaderProgram(
        \\#version 330 core
        \\layout (location = 0) in vec3 aPos;
        \\layout (location = 1) in vec2 aTexCoord;
        \\out vec2 TexCoord;
        \\void main()
        \\{
        \\    gl_Position = vec4(aPos, 1.0);
        \\    TexCoord = aTexCoord;
        \\}
    ,
        \\#version 330 core
        \\out vec4 FragColor;
        \\in vec2 TexCoord;
        \\uniform sampler2D ourTexture;
        \\void main()
        \\{
        \\    FragColor = texture(ourTexture, vec2(TexCoord.x, 1.0 - TexCoord.y));
        \\}
    );
    defer c.glDeleteProgram(shader_program);

    const vertices = [_]f32{
        0.5,  0.5,  0.0, 1.0, 1.0,
        0.5,  -0.5, 0.0, 1.0, 0.0,
        -0.5, -0.5, 0.0, 0.0, 0.0,
        -0.5, 0.5,  0.0, 0.0, 1.0,
    };
    const indices = [_]c.GLuint{
        0, 1, 3,
        1, 2, 3,
    };

    var vao: c.GLuint = undefined;
    c.glGenVertexArrays(1, &vao);
    defer c.glDeleteVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: c.GLuint = undefined;
    c.glGenBuffers(1, &vbo);
    defer c.glDeleteBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

    var ebo: c.GLuint = undefined;
    c.glGenBuffers(1, &ebo);
    defer c.glDeleteBuffers(1, &ebo);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(f32) * 5, @ptrFromInt(0));
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(f32) * 5, @ptrFromInt(@sizeOf(f32) * 3));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);

    c.glClearColor(0.2, 0.3, 0.3, 1.0);
    while (c.glfwWindowShouldClose(window) != c.GLFW_TRUE) {
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetFramebufferSize(window, &width, &height);
        c.glViewport(0, 0, width, height);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(shader_program);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glBindVertexArray(vao);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, @ptrFromInt(0));

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {d}: {s}", .{ err, description });
}

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS) {
        c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
    }
}

fn createShaderProgram(vertex: []const u8, fragment: []const u8) !c.GLuint {
    var success: c.GLint = undefined;

    const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertex_shader, 1, @ptrCast(&vertex), null);
    c.glCompileShader(vertex_shader);
    c.glGetShaderiv(vertex_shader, c.GL_COMPILE_STATUS, &success);
    if (success == c.GL_FALSE) {
        var buffer: [512]c.GLchar = undefined;
        c.glGetShaderInfoLog(vertex_shader, buffer.len, null, &buffer);
        const log: [*:0]c.GLchar = @ptrCast(&buffer);
        std.log.err("Vertex shader compilation failed: {s}", .{log});
        return error.VertexShaderCompilationFailed;
    }

    const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragment_shader, 1, @ptrCast(&fragment), null);
    c.glCompileShader(fragment_shader);
    c.glGetShaderiv(fragment_shader, c.GL_COMPILE_STATUS, &success);
    if (success == c.GL_FALSE) {
        var buffer: [512]c.GLchar = undefined;
        c.glGetShaderInfoLog(fragment_shader, buffer.len, null, &buffer);
        const log: [*:0]c.GLchar = @ptrCast(&buffer);
        std.log.err("Fragment shader compilation failed: {s}", .{log});
        return error.FragmentShaderCompilationFailed;
    }

    const shader_program = c.glCreateProgram();
    errdefer c.glDeleteProgram(shader_program);
    c.glAttachShader(shader_program, vertex_shader);
    c.glAttachShader(shader_program, fragment_shader);
    c.glLinkProgram(shader_program);
    c.glGetProgramiv(shader_program, c.GL_LINK_STATUS, &success);
    if (success == c.GL_FALSE) {
        var buffer: [512]c.GLchar = undefined;
        c.glGetProgramInfoLog(shader_program, buffer.len, null, &buffer);
        const log: [*:0]c.GLchar = @ptrCast(&buffer);
        std.log.err("Shader program linking failed: {s}", .{log});
        return error.ShaderProgramLinkingFailed;
    }

    return shader_program;
}

fn makeTexture(image: Image) c.GLuint {
    var texture: c.GLuint = undefined;
    c.glGenTextures(1, &texture);
    errdefer c.glDeleteTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_RED,
        @intCast(image.stride),
        @intCast(image.height),
        0,
        c.GL_RED,
        c.GL_UNSIGNED_BYTE,
        image.data.ptr,
    );
    c.glGenerateMipmap(c.GL_TEXTURE_2D);
    return texture;
}

const Image = struct {
    allocator: Allocator,
    stride: usize,
    width: usize,
    height: usize,
    data: []u8,

    pub fn init(alloc: Allocator, path: []const u8) !Image {
        var width: c_int = undefined;
        var height: c_int = undefined;
        const image = c.stbi_load(path.ptr, &width, &height, null, 1);
        if (image == null) {
            std.log.err(
                "Failed to load image {s}: {s}",
                .{ path, c.stbi_failure_reason() },
            );
            return error.ImageLoadingFailed;
        }
        defer c.stbi_image_free(image);

        const size: usize = @intCast(width * height);
        const data = try alloc.alloc(u8, size);
        @memcpy(data, image[0..size]);

        return .{
            .allocator = alloc,
            .stride = @intCast(width),
            .width = @intCast(width),
            .height = @intCast(height),
            .data = data,
        };
    }

    pub fn deinit(self: Image) void {
        self.allocator.free(self.data);
    }
};

fn getVideoFrame(alloc: Allocator, path: []const u8) !Image {
    var fmt_ctx: [*c]c.AVFormatContext = null;
    if (c.avformat_open_input(&fmt_ctx, path.ptr, null, null) < 0) {
        std.log.err("Could not open source file: {s}", .{path});
        return error.OpenInputFileFailed;
    }
    defer c.avformat_close_input(&fmt_ctx);

    if (c.avformat_find_stream_info(fmt_ctx, null) < 0) {
        return error.FindStreamInfoFailed;
    }

    const index = c.av_find_best_stream(fmt_ctx, c.AVMEDIA_TYPE_VIDEO, -1, -1, null, 0);
    if (index < 0) {
        return error.FindBestStreamFailed;
    }
    std.debug.print("stream index: {d}\n", .{index});

    const stream = fmt_ctx.*.streams[@intCast(index)];
    const decoder = c.avcodec_find_decoder(stream.*.codecpar.*.codec_id) orelse {
        return error.DecoderNotFound;
    };
    std.debug.print("Got a decoder: {s}\n", .{decoder.*.name});

    var dec_ctx = c.avcodec_alloc_context3(decoder) orelse {
        return error.CodecContextAllocationFailed;
    };
    defer c.avcodec_free_context(&dec_ctx);

    if (c.avcodec_parameters_to_context(dec_ctx, stream.*.codecpar) < 0) {
        return error.CopyCodecParametersFailed;
    }
    if (c.avcodec_open2(dec_ctx, decoder, null) < 0) {
        return error.OpenCodecFailed;
    }

    c.av_dump_format(fmt_ctx, 0, path.ptr, 0);

    var frame = c.av_frame_alloc();
    defer c.av_frame_free(&frame);

    var pkt = c.av_packet_alloc();
    defer c.av_packet_free(&pkt);

    var frame_count: usize = 0;
    while (c.av_read_frame(fmt_ctx, pkt) >= 0) {
        defer c.av_packet_unref(pkt);
        if (pkt.*.stream_index != index) {
            continue;
        }
        if (c.avcodec_send_packet(dec_ctx, pkt) < 0) {
            return error.SendPacketFailed;
        }
        const ret = c.avcodec_receive_frame(dec_ctx, frame);
        if (ret < 0) {
            std.debug.print("receive frame: {d} eof?{} again?{}\n", .{
                ret,
                ret == c.AVERROR_EOF,
                ret == c.AVERROR(c.EAGAIN),
            });
            continue;
        }
        frame_count += 1;
        if (frame_count == 1) {
            std.debug.print("received frame with format: {s}\n", .{c.av_get_pix_fmt_name(frame.*.format)});
            std.debug.print("received frame with size: {d}x{d}\n", .{ frame.*.width, frame.*.height });
            std.debug.print("received frame with line sizes: {d}\n", .{frame.*.linesize});
            break;
        }
    }

    const width: usize = @intCast(frame.*.width);
    const height: usize = @intCast(frame.*.height);
    const stride: usize = @intCast(frame.*.linesize[0]);

    const data = try alloc.alloc(u8, stride * height);
    @memcpy(data, frame.*.data[0][0 .. stride * height]);

    return .{
        .allocator = alloc,
        .stride = stride,
        .width = width,
        .height = height,
        .data = data,
    };
}
