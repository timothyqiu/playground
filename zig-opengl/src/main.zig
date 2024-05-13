const std = @import("std");
const c = @cImport({
    @cInclude("stb_image.h");
    @cInclude("glad/glad.h");
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    if (args.len < 2) {
        std.log.err("No image path given", .{});
        return error.InvalidArgs;
    }

    c.stbi_set_flip_vertically_on_load(c.GL_TRUE);
    const image = try Image.init(args[1]);
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
        std.log.err("Failed to load OpenGL context", .{});
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
        \\    FragColor = texture(ourTexture, TexCoord);
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
        c.GL_RGB,
        @intCast(image.width),
        @intCast(image.height),
        0,
        c.GL_RGB,
        c.GL_UNSIGNED_BYTE,
        image.data,
    );
    c.glGenerateMipmap(c.GL_TEXTURE_2D);
    return texture;
}

const Image = struct {
    width: usize,
    height: usize,
    data: [*]u8,

    pub fn init(path: []const u8) !Image {
        var width: c_int = undefined;
        var height: c_int = undefined;
        const data = c.stbi_load(path.ptr, &width, &height, null, 3);
        if (data == null) {
            std.log.err(
                "Failed to load image {s}: {s}",
                .{ path, c.stbi_failure_reason() },
            );
            return error.ImageLoadingFailed;
        }
        return .{
            .width = @intCast(width),
            .height = @intCast(height),
            .data = data,
        };
    }

    pub fn deinit(self: Image) void {
        c.stbi_image_free(self.data);
    }
};
