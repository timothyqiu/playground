const std = @import("std");
const c = @import("c.zig");
const Allocator = std.mem.Allocator;
const CommandPool = @import("CommandPool.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const Swapchain = @import("Swapchain.zig");

const VALIDATION_LAYERS = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
const DEVICE_EXTENSIONS = [_][*:0]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

var enable_validation_layers: bool = @import("builtin").mode == .Debug;

const Vec2 = extern struct { x: f32, y: f32 };
const Vec3 = extern struct { x: f32, y: f32, z: f32 };
const Vertex = extern struct {
    pos: Vec2,
    color: Vec3,

    fn getBindingDescription() c.VkVertexInputBindingDescription {
        return std.mem.zeroInit(c.VkVertexInputBindingDescription, .{
            .binding = 0,
            .stride = @as(u32, @sizeOf(Vertex)),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        });
    }

    fn getAttributeDescriptions() [2]c.VkVertexInputAttributeDescription {
        return [_]c.VkVertexInputAttributeDescription{
            std.mem.zeroInit(c.VkVertexInputAttributeDescription, .{
                .binding = 0,
                .location = 0,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @as(u32, @offsetOf(Vertex, "pos")),
            }),
            std.mem.zeroInit(c.VkVertexInputAttributeDescription, .{
                .binding = 0,
                .location = 1,
                .format = c.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @as(u32, @offsetOf(Vertex, "color")),
            }),
        };
    }
};

var vertex_buffer: c.VkBuffer = undefined;

const VERTICES = [_]Vertex{
    .{ .pos = .{ .x = 0.0, .y = -0.5 }, .color = .{ .x = 1.0, .y = 0.0, .z = 0.0 } },
    .{ .pos = .{ .x = 0.5, .y = 0.5 }, .color = .{ .x = 0.0, .y = 1.0, .z = 0.0 } },
    .{ .pos = .{ .x = -0.5, .y = 0.5 }, .color = .{ .x = 0.0, .y = 0.0, .z = 1.0 } },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const window = try initWindow(800, 600, "Hello World");
    defer deinitWindow(window);

    const instance = try initInstance(allocator);
    defer deinitInstance(instance);

    const debug_messenger = try initDebugMessenger(instance);
    defer deinitDebugMessenger(instance, debug_messenger);

    var surface: c.VkSurfaceKHR = undefined;
    if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VK_SUCCESS) {
        return error.GlfwCreateWindowSurfaceFailed;
    }
    defer c.vkDestroySurfaceKHR(instance, surface, null);

    const physical_device = try pickPhysicalDevice(allocator, instance, surface) orelse {
        return error.NoSuitablePhysicalDevice;
    };

    const indices = try findQueueFamilies(allocator, physical_device, surface) orelse {
        return error.NoSuitableQueueFamily;
    };

    const device = try initLogicalDevice(physical_device, indices);
    defer deinitLogicalDevice(device);

    var graphics_queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(device, indices.graphics_family, 0, &graphics_queue);

    var present_queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(device, indices.present_family, 0, &present_queue);

    var maybe_swapchain: ?Swapchain = try Swapchain.init(
        allocator,
        physical_device,
        window,
        device,
        surface,
        indices.graphics_family,
        indices.present_family,
    );
    defer if (maybe_swapchain) |swapchain| {
        swapchain.deinit();
    };

    const pipeline = try initGraphicsPipeline(allocator, device, maybe_swapchain.?.render_pass);
    defer deinitGraphicsPipeline(device, pipeline);

    const command_pool = try CommandPool.init(device, indices.graphics_family);
    defer command_pool.deinit();

    const buffer_info = std.mem.zeroInit(c.VkBufferCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = @as(u64, @sizeOf(Vertex) * VERTICES.len),
        .usage = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    });

    if (c.vkCreateBuffer(device, &buffer_info, null, &vertex_buffer) != c.VK_SUCCESS) {
        return error.VkCreateBufferFailed;
    }
    defer c.vkDestroyBuffer(device, vertex_buffer, null);

    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(device, vertex_buffer, &mem_requirements);

    const alloc_info = std.mem.zeroInit(c.VkMemoryAllocateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_requirements.size,
        .memoryTypeIndex = try findMemoryType(
            physical_device,
            mem_requirements.memoryTypeBits,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        ),
    });
    var vertex_buffer_memory: c.VkDeviceMemory = undefined;
    if (c.vkAllocateMemory(device, &alloc_info, null, &vertex_buffer_memory) != c.VK_SUCCESS) {
        return error.VkAllocateMemoryFailed;
    }
    defer c.vkFreeMemory(device, vertex_buffer_memory, null);

    if (c.vkBindBufferMemory(device, vertex_buffer, vertex_buffer_memory, 0) != c.VK_SUCCESS) {
        return error.VkBindBufferMemoryFailed;
    }
    {
        var data: ?*anyopaque = undefined;
        if (c.vkMapMemory(device, vertex_buffer_memory, 0, mem_requirements.size, 0, &data) != c.VK_SUCCESS) {
            return error.VkMapMemoryFailed;
        }
        defer c.vkUnmapMemory(device, vertex_buffer_memory);

        @memcpy(@as([*]Vertex, @alignCast(@ptrCast(data))), &VERTICES);
    }

    const MAX_FRAMES_IN_FLIGHT = 2;
    const command_buffers = try CommandBuffer.init(allocator, device, command_pool.command_pool, MAX_FRAMES_IN_FLIGHT);
    defer command_buffers.deinit();

    var current_frame: usize = 0;
    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        c.glfwPollEvents();

        const swapchain = maybe_swapchain.?;

        drawFrame(
            current_frame,
            device,
            graphics_queue,
            present_queue,
            swapchain,
            pipeline,
            command_buffers,
        ) catch |e| {
            switch (e) {
                error.FramebufferResized => {
                    var width: c_int = undefined;
                    var height: c_int = undefined;
                    c.glfwGetFramebufferSize(window, &width, &height);
                    while (width == 0 or height == 0) {
                        c.glfwGetFramebufferSize(window, &width, &height);
                        c.glfwWaitEvents();
                    }

                    _ = c.vkDeviceWaitIdle(device);

                    swapchain.deinit();

                    maybe_swapchain = null;
                    maybe_swapchain = try Swapchain.init(
                        allocator,
                        physical_device,
                        window,
                        device,
                        surface,
                        indices.graphics_family,
                        indices.present_family,
                    );
                },
                else => {
                    _ = c.vkDeviceWaitIdle(device);
                    return e;
                },
            }
        };

        current_frame = (current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    std.log.info("Exiting", .{});
    if (c.vkDeviceWaitIdle(device) != c.VK_SUCCESS) {
        return error.VkDeviceWaitIdleFailed;
    }
}

fn glfwErrorCallback(error_code: c_int, description: [*c]const u8) callconv(.C) void {
    _ = error_code;
    std.log.warn("GLFW error: {s}\n", .{description});
}

fn vulkanDebugCallback(
    message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_type: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.C) c.VkBool32 {
    _ = user_data;
    _ = message_type;
    _ = message_severity;

    std.debug.print("Validation layer: {s}\n", .{std.mem.sliceTo(callback_data.*.pMessage, 0)});
    return c.VK_FALSE;
}

fn dumpInstanceExtensions(allocator: Allocator) !void {
    var extension_count: u32 = undefined;
    switch (c.vkEnumerateInstanceExtensionProperties(null, &extension_count, null)) {
        c.VK_SUCCESS => {},
        else => return error.VkEnumerateInstanceExtensionPropertiesFailed,
    }

    if (extension_count == 0) {
        std.debug.print("No extension available.\n", .{});
        return;
    }

    var extensions = try allocator.alloc(c.VkExtensionProperties, extension_count);
    defer allocator.free(extensions);

    switch (c.vkEnumerateInstanceExtensionProperties(null, &extension_count, extensions.ptr)) {
        c.VK_SUCCESS, c.VK_INCOMPLETE => {},
        else => return error.VkEnumerateInstanceExtensionPropertiesFailed,
    }

    std.debug.print("Extensions available:\n", .{});
    for (extensions) |extension| {
        std.debug.print("\t{s}\n", .{std.mem.sliceTo(&extension.extensionName, 0)});
    }
}

fn hasValidationLayerSupport(allocator: Allocator) bool {
    var layer_count: u32 = undefined;
    if (c.vkEnumerateInstanceLayerProperties(&layer_count, null) != c.VK_SUCCESS) {
        return false;
    }

    var available_layers = allocator.alloc(c.VkLayerProperties, layer_count) catch return false;
    defer allocator.free(available_layers);

    if (c.vkEnumerateInstanceLayerProperties(&layer_count, available_layers.ptr) != c.VK_SUCCESS) {
        return false;
    }

    for (VALIDATION_LAYERS) |layer_name| {
        for (available_layers) |available_layer| {
            if (std.mem.eql(
                u8,
                std.mem.sliceTo(layer_name, 0),
                std.mem.sliceTo(&available_layer.layerName, 0),
            )) {
                break;
            }
        } else {
            return false;
        }
    }

    return true;
}

fn getRequiredExtensions(allocator: Allocator) ![][*c]const u8 {
    var glfw_extension_count: u32 = undefined;
    const glfw_extensions = c.glfwGetRequiredInstanceExtensions(&glfw_extension_count) orelse {
        return error.GlfwGetRequiredInstanceExtensionsFailed;
    };

    const required_extension_count = if (enable_validation_layers) glfw_extension_count + 1 else glfw_extension_count;
    var extensions = try allocator.alloc([*c]const u8, required_extension_count);
    @memcpy(extensions.ptr, glfw_extensions[0..glfw_extension_count]);

    if (enable_validation_layers) {
        extensions[glfw_extension_count] = c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
    }
    return extensions;
}

fn initWindow(width: c_int, height: c_int, title: [:0]const u8) !*c.GLFWwindow {
    std.log.info("Initializing Window", .{});

    _ = c.glfwSetErrorCallback(glfwErrorCallback);

    if (c.glfwInit() != c.GLFW_TRUE) {
        return error.GlfwInitFailed;
    }
    errdefer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    return c.glfwCreateWindow(width, height, title, null, null) orelse {
        return error.GlfwCreateWindowFailed;
    };
}

fn deinitWindow(window: *c.GLFWwindow) void {
    std.log.info("Destroying Window", .{});
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}

fn initInstance(allocator: Allocator) !c.VkInstance {
    std.log.info("Creating Vulkan instance", .{});

    if (enable_validation_layers and !hasValidationLayerSupport(allocator)) {
        enable_validation_layers = false;
        std.log.warn("Validation layers requested, but not available!\n", .{});
    }

    const app_info = std.mem.zeroInit(c.VkApplicationInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Hello World",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
    });

    const required_extensions = try getRequiredExtensions(allocator);
    defer allocator.free(required_extensions);

    var create_info = std.mem.zeroInit(c.VkInstanceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @as(u32, @intCast(required_extensions.len)),
        .ppEnabledExtensionNames = required_extensions.ptr,
    });
    if (enable_validation_layers) {
        create_info.enabledLayerCount = @intCast(VALIDATION_LAYERS.len);
        create_info.ppEnabledLayerNames = &VALIDATION_LAYERS;
    }

    var debug_create_info: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
    if (enable_validation_layers) {
        populateDebugMessengerCreateInfo(&debug_create_info);
        create_info.pNext = &debug_create_info;
    }

    var instance: c.VkInstance = undefined;
    switch (c.vkCreateInstance(&create_info, null, &instance)) {
        c.VK_SUCCESS => {},
        c.VK_ERROR_EXTENSION_NOT_PRESENT => {
            std.debug.print("Extensions required:\n", .{});
            for (required_extensions) |extension| {
                std.debug.print("\t{s}\n", .{std.mem.sliceTo(extension, 0)});
            }
            dumpInstanceExtensions(allocator) catch {};
            return error.ExtensionNotPresent;
        },
        else => return error.VkCreateInstanceFailed,
    }

    return instance;
}

fn deinitInstance(instance: c.VkInstance) void {
    std.log.info("Destroying Vulkan instance", .{});
    c.vkDestroyInstance(instance, null);
}

fn createDebugUtilsMessengerEXT(
    instance: c.VkInstance,
    create_info: *const c.VkDebugUtilsMessengerCreateInfoEXT,
    allocator: ?*const c.VkAllocationCallbacks,
    debug_messenger: *c.VkDebugUtilsMessengerEXT,
) c.VkResult {
    const func: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(
        instance,
        "vkCreateDebugUtilsMessengerEXT",
    ));
    if (func) |f| {
        return f(instance, create_info, allocator, debug_messenger);
    }
    return c.VK_ERROR_EXTENSION_NOT_PRESENT;
}

fn destroyDebugUtilsMessengerEXT(
    instance: c.VkInstance,
    debug_messenger: c.VkDebugUtilsMessengerEXT,
    allocator: ?*const c.VkAllocationCallbacks,
) void {
    const func: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(
        instance,
        "vkDestroyDebugUtilsMessengerEXT",
    ));
    if (func) |f| {
        f(instance, debug_messenger, allocator);
    }
}

fn populateDebugMessengerCreateInfo(
    create_info: *c.VkDebugUtilsMessengerCreateInfoEXT,
) void {
    create_info.* = std.mem.zeroInit(c.VkDebugUtilsMessengerCreateInfoEXT, .{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = vulkanDebugCallback,
        .pUserData = null,
    });
}

fn initDebugMessenger(instance: c.VkInstance) !?c.VkDebugUtilsMessengerEXT {
    if (!enable_validation_layers) {
        return null;
    }
    std.log.info("Setting up debug messenger", .{});

    var create_info: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
    populateDebugMessengerCreateInfo(&create_info);

    var debug_messenger: c.VkDebugUtilsMessengerEXT = undefined;
    if (createDebugUtilsMessengerEXT(
        instance,
        &create_info,
        null,
        &debug_messenger,
    ) != c.VK_SUCCESS) {
        return error.VkCreateDebugUtilsMessengerEXTFailed;
    }
    return debug_messenger;
}

fn deinitDebugMessenger(
    instance: c.VkInstance,
    debug_messenger: ?c.VkDebugUtilsMessengerEXT,
) void {
    if (debug_messenger) |messenger| {
        std.log.info("Destroying debug messenger", .{});
        destroyDebugUtilsMessengerEXT(instance, messenger, null);
    }
}

fn isDeviceSuitable(
    allocator: Allocator,
    physical_device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
) bool {
    if (!checkDeviceExtensionSupport(allocator, physical_device)) {
        return false;
    }

    var format_count: u32 = undefined;
    if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(
        physical_device,
        surface,
        &format_count,
        null,
    ) != c.VK_SUCCESS or format_count == 0) {
        return false;
    }

    var present_mode_count: u32 = undefined;
    if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(
        physical_device,
        surface,
        &present_mode_count,
        null,
    ) != c.VK_SUCCESS or present_mode_count == 0) {
        return false;
    }

    const indices = findQueueFamilies(allocator, physical_device, surface) catch return false;
    return indices != null;
}

const QueueFamilyIndices = struct {
    graphics_family: u32,
    present_family: u32,
};

fn findQueueFamilies(
    allocator: Allocator,
    device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
) !?QueueFamilyIndices {
    var queue_family_count: u32 = undefined;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

    var queue_families = try allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
    defer allocator.free(queue_families);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

    var graphics_family: ?usize = null;
    var present_family: ?usize = null;
    for (queue_families, 0..) |queue_family, index| {
        if (queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            graphics_family = index;
        }

        var present_support: c.VkBool32 = undefined;
        if (c.vkGetPhysicalDeviceSurfaceSupportKHR(
            device,
            @intCast(index),
            surface,
            &present_support,
        ) != c.VK_SUCCESS) {
            continue;
        }
        if (present_support == c.VK_TRUE) {
            present_family = index;
        }
    }

    if (graphics_family != null and present_family != null) {
        return .{
            .graphics_family = @intCast(graphics_family.?),
            .present_family = @intCast(present_family.?),
        };
    }

    return null;
}

fn pickPhysicalDevice(
    allocator: Allocator,
    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,
) !?c.VkPhysicalDevice {
    std.log.info("Picking physical device", .{});

    var device_count: u32 = undefined;
    if (c.vkEnumeratePhysicalDevices(instance, &device_count, null) != c.VK_SUCCESS) {
        return error.VkEnumeratePhysicalDevicesFailed;
    }
    if (device_count == 0) {
        return null;
    }
    var devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
    defer allocator.free(devices);
    switch (c.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr)) {
        c.VK_SUCCESS, c.VK_INCOMPLETE => {},
        else => return error.VkEnumeratePhysicalDevicesFailed,
    }

    var physical_device: c.VkPhysicalDevice = null;
    for (devices) |device| {
        if (isDeviceSuitable(allocator, device, surface)) {
            physical_device = device;
            break;
        }
    }
    return physical_device;
}

fn initLogicalDevice(
    physical_device: c.VkPhysicalDevice,
    indices: QueueFamilyIndices,
) !c.VkDevice {
    std.log.info("Creating logical device", .{});

    var queue_priority: f32 = 1.0;
    const queue_create_infos = [_]c.VkDeviceQueueCreateInfo{
        std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = indices.graphics_family,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        }),
        std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = indices.present_family,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        }),
    };

    const device_features = std.mem.zeroInit(c.VkPhysicalDeviceFeatures, .{});

    var create_info = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = @as(u32, @intCast(queue_create_infos.len)),
        .pQueueCreateInfos = &queue_create_infos,
        .pEnabledFeatures = &device_features,
        .enabledExtensionCount = @as(u32, @intCast(DEVICE_EXTENSIONS.len)),
        .ppEnabledExtensionNames = &DEVICE_EXTENSIONS,
    });
    if (enable_validation_layers) {
        create_info.enabledLayerCount = @intCast(VALIDATION_LAYERS.len);
        create_info.ppEnabledLayerNames = &VALIDATION_LAYERS;
    }

    var device: c.VkDevice = undefined;
    if (c.vkCreateDevice(physical_device, &create_info, null, &device) != c.VK_SUCCESS) {
        return error.VkCreateDeviceFailed;
    }
    return device;
}

fn deinitLogicalDevice(device: c.VkDevice) void {
    std.log.info("Destroying logical device", .{});
    c.vkDestroyDevice(device, null);
}

fn checkDeviceExtensionSupport(allocator: Allocator, device: c.VkPhysicalDevice) bool {
    var extension_count: u32 = undefined;
    if (c.vkEnumerateDeviceExtensionProperties(
        device,
        null,
        &extension_count,
        null,
    ) != c.VK_SUCCESS) {
        return false;
    }

    var available_extensions = allocator.alloc(
        c.VkExtensionProperties,
        extension_count,
    ) catch return false;
    defer allocator.free(available_extensions);
    if (c.vkEnumerateDeviceExtensionProperties(
        device,
        null,
        &extension_count,
        available_extensions.ptr,
    ) != c.VK_SUCCESS) {
        return false;
    }

    for (DEVICE_EXTENSIONS) |extension| {
        for (available_extensions) |available_extension| {
            if (std.mem.eql(
                u8,
                std.mem.sliceTo(extension, 0),
                std.mem.sliceTo(&available_extension.extensionName, 0),
            )) {
                break;
            }
        } else {
            return false;
        }
    }

    return true;
}

const Pipeline = struct {
    pipeline: c.VkPipeline,
    layout: c.VkPipelineLayout,
};

fn initGraphicsPipeline(allocator: Allocator, device: c.VkDevice, render_pass: c.VkRenderPass) !Pipeline {
    std.log.info("Creating graphics pipeline", .{});

    const vert_shader_code = try std.fs.cwd().readFileAlloc(allocator, "assets/shaders/vert.spv", 10240);
    defer allocator.free(vert_shader_code);
    const frag_shader_code = try std.fs.cwd().readFileAlloc(allocator, "assets/shaders/frag.spv", 10240);
    defer allocator.free(frag_shader_code);

    const vert_shader_module = try initShaderModule(device, vert_shader_code);
    defer c.vkDestroyShaderModule(device, vert_shader_module, null);
    const frag_shader_module = try initShaderModule(device, frag_shader_code);
    defer c.vkDestroyShaderModule(device, frag_shader_module, null);

    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{
        std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
            .module = vert_shader_module,
            .pName = "main",
        }),
        std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = frag_shader_module,
            .pName = "main",
        }),
    };

    const attribute_descriptions = Vertex.getAttributeDescriptions();
    const vertex_input_info = std.mem.zeroInit(c.VkPipelineVertexInputStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &Vertex.getBindingDescription(),
        .vertexAttributeDescriptionCount = @as(u32, @intCast(attribute_descriptions.len)),
        .pVertexAttributeDescriptions = &attribute_descriptions,
    });

    const input_assembly = std.mem.zeroInit(c.VkPipelineInputAssemblyStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    });

    const viewport_state = std.mem.zeroInit(c.VkPipelineViewportStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .scissorCount = 1,
    });

    const rasterizer = std.mem.zeroInit(c.VkPipelineRasterizationStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
    });

    const multisampling = std.mem.zeroInit(c.VkPipelineMultisampleStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
    });

    const color_blend_attachment = std.mem.zeroInit(c.VkPipelineColorBlendAttachmentState, .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
    });
    const color_blending = std.mem.zeroInit(c.VkPipelineColorBlendStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
    });

    const dynamic_states = [_]c.VkDynamicState{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
    };
    const dynamic_state = std.mem.zeroInit(c.VkPipelineDynamicStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = @as(u32, @intCast(dynamic_states.len)),
        .pDynamicStates = &dynamic_states,
    });

    const pipeline_layout_info = std.mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    });

    var pipeline_layout: c.VkPipelineLayout = undefined;
    if (c.vkCreatePipelineLayout(device, &pipeline_layout_info, null, &pipeline_layout) != c.VK_SUCCESS) {
        return error.VkCreatePipelineLayoutFailed;
    }
    errdefer c.vkDestroyPipelineLayout(device, pipeline_layout, null);

    const pipeline_info = std.mem.zeroInit(c.VkGraphicsPipelineCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = @as(u32, @intCast(shader_stages.len)),
        .pStages = &shader_stages,
        .pVertexInputState = &vertex_input_info,
        .pInputAssemblyState = &input_assembly,
        .pViewportState = &viewport_state,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &color_blending,
        .pDynamicState = &dynamic_state,
        .layout = pipeline_layout,
        .renderPass = render_pass,
        .subpass = 0,
    });

    var pipeline: c.VkPipeline = undefined;
    if (c.vkCreateGraphicsPipelines(
        device,
        null,
        1,
        &pipeline_info,
        null,
        &pipeline,
    ) != c.VK_SUCCESS) {
        return error.VkCreateGraphicsPipelinesFailed;
    }

    return .{
        .pipeline = pipeline,
        .layout = pipeline_layout,
    };
}

fn deinitGraphicsPipeline(device: c.VkDevice, pipeline: Pipeline) void {
    std.log.info("Destroying graphics pipeline", .{});
    c.vkDestroyPipelineLayout(device, pipeline.layout, null);
    c.vkDestroyPipeline(device, pipeline.pipeline, null);
}

fn initShaderModule(device: c.VkDevice, code: []const u8) !c.VkShaderModule {
    const create_info = std.mem.zeroInit(c.VkShaderModuleCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = @as(u32, @intCast(code.len)),
        .pCode = @as([*]const u32, @alignCast(@ptrCast(code.ptr))),
    });

    var shader_module: c.VkShaderModule = undefined;
    if (c.vkCreateShaderModule(device, &create_info, null, &shader_module) != c.VK_SUCCESS) {
        return error.VkCreateShaderModuleFailed;
    }
    return shader_module;
}

fn recordCommandBuffer(
    command_buffer: c.VkCommandBuffer,
    swapchain: Swapchain,
    render_pass: c.VkRenderPass,
    framebuffer: c.VkFramebuffer,
    pipeline: Pipeline,
) !void {
    const begin_info = std.mem.zeroInit(c.VkCommandBufferBeginInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    });

    if (c.vkBeginCommandBuffer(command_buffer, &begin_info) != c.VK_SUCCESS) {
        return error.VkBeginCommandBufferFailed;
    }

    const render_pass_info = std.mem.zeroInit(c.VkRenderPassBeginInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = render_pass,
        .framebuffer = framebuffer,
        .renderArea = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = swapchain.extent,
        },
        .clearValueCount = 1,
        .pClearValues = &[_]c.VkClearValue{
            .{ .color = .{ .float32 = .{ 0, 0, 0, 1 } } },
        },
    });

    {
        c.vkCmdBeginRenderPass(
            command_buffer,
            &render_pass_info,
            c.VK_SUBPASS_CONTENTS_INLINE,
        );
        defer c.vkCmdEndRenderPass(command_buffer);

        c.vkCmdBindPipeline(
            command_buffer,
            c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            pipeline.pipeline,
        );

        const viewport = c.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(swapchain.extent.width),
            .height = @floatFromInt(swapchain.extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };
        c.vkCmdSetViewport(command_buffer, 0, 1, &viewport);

        const scissor = c.VkRect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = swapchain.extent,
        };
        c.vkCmdSetScissor(command_buffer, 0, 1, &scissor);

        c.vkCmdBindPipeline(
            command_buffer,
            c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            pipeline.pipeline,
        );

        const offset: c.VkDeviceSize = 0;
        c.vkCmdBindVertexBuffers(
            command_buffer,
            0,
            1,
            &vertex_buffer,
            &offset,
        );

        c.vkCmdDraw(command_buffer, 3, 1, 0, 0);
    }

    if (c.vkEndCommandBuffer(command_buffer) != c.VK_SUCCESS) {
        return error.VkEndCommandBufferFailed;
    }
}

fn drawFrame(
    current_frame: usize,
    device: c.VkDevice,
    graphics_queue: c.VkQueue,
    present_queue: c.VkQueue,
    swapchain: Swapchain,
    pipeline: Pipeline,
    command_buffers: CommandBuffer,
) !void {
    if (c.vkWaitForFences(device, 1, &command_buffers.in_flight_fences[current_frame], c.VK_TRUE, std.math.maxInt(u64)) != c.VK_SUCCESS) {
        return error.VkWaitForFencesFailed;
    }

    var image_index: u32 = undefined;
    switch (c.vkAcquireNextImageKHR(
        device,
        swapchain.swapchain,
        std.math.maxInt(u64),
        command_buffers.image_available_semaphores[current_frame],
        @ptrCast(c.VK_NULL_HANDLE),
        &image_index,
    )) {
        c.VK_SUCCESS => {},
        c.VK_SUBOPTIMAL_KHR, c.VK_ERROR_OUT_OF_DATE_KHR => return error.FramebufferResized,
        else => return error.VkAcquireNextImageKHRFailed,
    }

    if (c.vkResetFences(device, 1, &command_buffers.in_flight_fences[current_frame]) != c.VK_SUCCESS) {
        return error.VkResetFencesFailed;
    }

    if (c.vkResetCommandBuffer(command_buffers.command_buffers[current_frame], 0) != c.VK_SUCCESS) {
        return error.VkResetCommandBufferFailed;
    }
    try recordCommandBuffer(
        command_buffers.command_buffers[current_frame],
        swapchain,
        swapchain.render_pass,
        swapchain.framebuffers[image_index],
        pipeline,
    );

    const submit_info = std.mem.zeroInit(c.VkSubmitInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &command_buffers.image_available_semaphores[current_frame],
        .pWaitDstStageMask = @as([*]const c.VkPipelineStageFlags, @ptrCast(&c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)),
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffers.command_buffers[current_frame],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &command_buffers.render_finished_semaphores[current_frame],
    });
    if (c.vkQueueSubmit(graphics_queue, 1, &submit_info, command_buffers.in_flight_fences[current_frame]) != c.VK_SUCCESS) {
        return error.VkQueueSubmitFailed;
    }

    const present_info = std.mem.zeroInit(c.VkPresentInfoKHR, .{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &command_buffers.render_finished_semaphores[current_frame],
        .swapchainCount = 1,
        .pSwapchains = &swapchain.swapchain,
        .pImageIndices = &image_index,
    });
    switch (c.vkQueuePresentKHR(present_queue, &present_info)) {
        c.VK_SUCCESS => {},
        c.VK_SUBOPTIMAL_KHR, c.VK_ERROR_OUT_OF_DATE_KHR => return error.FramebufferResized,
        else => return error.VkQueuePresentKHRFailed,
    }
}

fn findMemoryType(physical_device: c.VkPhysicalDevice, type_filter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

    for (mem_properties.memoryTypes[0..mem_properties.memoryTypeCount], 0..) |mem_type, index| {
        if (type_filter & (@as(u32, 1) << @intCast(index)) != 0 and mem_type.propertyFlags & properties == properties) {
            return @intCast(index);
        }
    }
    return error.NoSuitableMemoryType;
}
