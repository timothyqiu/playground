const std = @import("std");
const c = @import("c.zig");
const Allocator = std.mem.Allocator;
const VideoFrame = @import("decoder.zig").VideoFrame;

const Self = @This();

const Action = enum(u8) {
    toggle_pause,
    step,
};
const ActionQueue = std.fifo.LinearFifo(Action, .Dynamic);

allocator: Allocator,
window: *c.GLFWwindow,
y_texture: c.GLuint,
u_texture: c.GLuint,
v_texture: c.GLuint,
video_shader_program: c.GLuint,
video_quad: Quad,
progress_shader_program: c.GLuint,
progress_quad: Quad,
width_ratio: f32 = 1.0,
image_aspect_ratio: f32 = 1.0,
progress: f32 = 0.0,
actions: ActionQueue,

pub fn init(allocator: Allocator) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    // GLFW.
    if (c.glfwInit() == c.GLFW_FALSE) {
        std.log.err("Failed to initialize GLFW: {d}", .{c.glfwGetError(null)});
        return error.GlfwInitialization;
    }
    errdefer c.glfwTerminate();

    _ = c.glfwSetErrorCallback(errorCallback);

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    const window = c.glfwCreateWindow(640, 480, "My Title", null, null) orelse {
        std.log.err("Failed to create window: {d}", .{c.glfwGetError(null)});
        return error.CreateWindow;
    };
    errdefer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);
    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == 0) {
        std.log.err("Failed to load OpenGL dec_ctx", .{});
        return error.LoadOpenGLContext;
    }

    c.glfwSwapInterval(0); // Turn off V-Sync.
    c.glfwSetWindowUserPointer(window, self);
    _ = c.glfwSetKeyCallback(window, keyCallback);

    // OpenGL stuff.
    var textures: [3]c.GLuint = undefined;
    c.glGenTextures(textures.len, &textures);
    errdefer c.glDeleteTextures(textures.len, &textures);
    for (textures) |texture| {
        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    }

    const video_shader_program = try createShaderProgram(@embedFile("Gui/video_vertex.glsl"), @embedFile("Gui/video_fragment.glsl"));
    errdefer c.glDeleteProgram(video_shader_program);
    const video_quad = Quad.init();
    errdefer video_quad.deinit();

    const progress_shader_program = try createShaderProgram(@embedFile("Gui/progress_vertex.glsl"), @embedFile("Gui/progress_fragment.glsl"));
    errdefer c.glDeleteProgram(progress_shader_program);
    const progress_quad = Quad.init();
    errdefer progress_quad.deinit();

    c.glClearColor(0.0, 0.0, 0.0, 1.0);

    self.allocator = allocator;
    self.window = window;
    self.y_texture = textures[0];
    self.u_texture = textures[1];
    self.v_texture = textures[2];
    self.video_shader_program = video_shader_program;
    self.progress_shader_program = progress_shader_program;
    self.video_quad = video_quad;
    self.progress_quad = progress_quad;
    self.actions = ActionQueue.init(allocator);
    errdefer self.action.deinit();

    return self;
}

pub fn deinit(self: *Self) void {
    self.video_quad.deinit();
    self.progress_quad.deinit();
    var textures = [_]c.GLuint{
        self.y_texture,
        self.u_texture,
        self.v_texture,
    };
    c.glDeleteTextures(textures.len, &textures);
    c.glDeleteProgram(self.video_shader_program);
    c.glDeleteProgram(self.progress_shader_program);
    c.glfwDestroyWindow(self.window);
    c.glfwTerminate();
    self.actions.deinit();
    self.allocator.destroy(self);
}

pub fn shouldClose(self: *Self) bool {
    return c.glfwWindowShouldClose(self.window) == c.GLFW_TRUE;
}

pub fn swapFrame(self: *Self, frame: VideoFrame) void {
    var ratio: f32 = @floatFromInt(frame.width);
    ratio /= @floatFromInt(frame.stride);
    self.width_ratio = ratio;

    var aspect_ratio: f32 = @floatFromInt(frame.width);
    aspect_ratio /= @floatFromInt(frame.height);
    self.image_aspect_ratio = aspect_ratio;

    self.progress = @floatCast(frame.pts / frame.duration);

    c.glBindTexture(c.GL_TEXTURE_2D, self.y_texture);
    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_RED,
        @intCast(frame.stride),
        @intCast(frame.height),
        0,
        c.GL_RED,
        c.GL_UNSIGNED_BYTE,
        frame.y.ptr,
    );

    c.glBindTexture(c.GL_TEXTURE_2D, self.u_texture);
    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_RED,
        @intCast(frame.stride / 2),
        @intCast(frame.height / 2),
        0,
        c.GL_RED,
        c.GL_UNSIGNED_BYTE,
        frame.u.ptr,
    );

    c.glBindTexture(c.GL_TEXTURE_2D, self.v_texture);
    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_RED,
        @intCast(frame.stride / 2),
        @intCast(frame.height / 2),
        0,
        c.GL_RED,
        c.GL_UNSIGNED_BYTE,
        frame.v.ptr,
    );
}

pub fn getNextAction(self: *Self) ?Action {
    return self.actions.readItem();
}

pub fn step(self: *Self) void {
    c.glfwPollEvents();

    var width: c_int = undefined;
    var height: c_int = undefined;
    c.glfwGetFramebufferSize(self.window, &width, &height);
    c.glViewport(0, 0, width, height);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    var window_aspect_ratio: f32 = @floatFromInt(width);
    window_aspect_ratio /= @floatFromInt(height);
    const aspect_ratio_ratio = window_aspect_ratio / self.image_aspect_ratio;

    c.glUseProgram(self.video_shader_program);
    c.glUniform1i(c.glGetUniformLocation(self.video_shader_program, "luma"), 0);
    c.glUniform1i(c.glGetUniformLocation(self.video_shader_program, "cb"), 1);
    c.glUniform1i(c.glGetUniformLocation(self.video_shader_program, "cr"), 2);
    c.glUniform1f(c.glGetUniformLocation(self.video_shader_program, "width_ratio"), self.width_ratio);
    c.glUniform1f(c.glGetUniformLocation(self.video_shader_program, "aspect_ratio_ratio"), aspect_ratio_ratio);

    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, self.y_texture);
    c.glActiveTexture(c.GL_TEXTURE1);
    c.glBindTexture(c.GL_TEXTURE_2D, self.u_texture);
    c.glActiveTexture(c.GL_TEXTURE2);
    c.glBindTexture(c.GL_TEXTURE_2D, self.v_texture);

    self.video_quad.render();

    c.glUseProgram(self.progress_shader_program);
    c.glUniform1f(c.glGetUniformLocation(self.progress_shader_program, "progress"), self.progress);

    self.progress_quad.render();

    c.glfwSwapBuffers(self.window);
}

fn createShaderProgram(vertex: [:0]const u8, fragment: [:0]const u8) !c.GLuint {
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

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {d}: {s}", .{ err, description });
}

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;

    if (action != c.GLFW_PRESS) {
        return;
    }

    const self: *Self = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window).?));
    switch (key) {
        c.GLFW_KEY_ESCAPE => c.glfwSetWindowShouldClose(window, c.GLFW_TRUE),

        c.GLFW_KEY_SPACE => self.actions.writeItem(.toggle_pause) catch |err| {
            std.log.err("Failed to write action: {}", .{err});
        },
        c.GLFW_KEY_N => self.actions.writeItem(.step) catch |err| {
            std.log.err("Failed to write action: {}", .{err});
        },

        else => {},
    }
}

const Quad = struct {
    vao: c.GLuint,
    vbo: c.GLuint,

    pub fn init() Quad {
        const vertices = [_]f32{
            -1.0, 1.0,
            -1.0, -1.0,
            1.0,  1.0,
            1.0,  -1.0,
        };

        var vbo: c.GLuint = undefined;
        c.glGenBuffers(1, &vbo);

        var vao: c.GLuint = undefined;
        c.glGenVertexArrays(1, &vao);

        c.glBindVertexArray(vao);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(f32) * 2, @ptrFromInt(0));
        c.glEnableVertexAttribArray(0);

        return .{
            .vao = vao,
            .vbo = vbo,
        };
    }

    pub fn deinit(self: Quad) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
    }

    pub fn render(self: Quad) void {
        c.glBindVertexArray(self.vao);
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
    }
};
