const std = @import("std");
const c = @import("c.zig");
const Allocator = std.mem.Allocator;
const Self = @This();

command_buffers: []c.VkCommandBuffer,
image_available_semaphores: []c.VkSemaphore,
render_finished_semaphores: []c.VkSemaphore,
in_flight_fences: []c.VkFence,

allocator: Allocator,
device: c.VkDevice,
command_pool: c.VkCommandPool,

pub fn init(
    allocator: Allocator,
    device: c.VkDevice,
    command_pool: c.VkCommandPool,
    count: u32,
) !Self {
    std.log.info("Creating command buffer", .{});

    const alloc_info = std.mem.zeroInit(c.VkCommandBufferAllocateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = command_pool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = count,
    });

    var command_buffers = try allocator.alloc(c.VkCommandBuffer, count);
    errdefer allocator.free(command_buffers);

    if (c.vkAllocateCommandBuffers(
        device,
        &alloc_info,
        command_buffers.ptr,
    ) != c.VK_SUCCESS) {
        return error.VkAllocateCommandBuffersFailed;
    }
    errdefer c.vkFreeCommandBuffers(device, command_pool, count, command_buffers.ptr);

    var image_available_semaphores = try allocator.alloc(c.VkSemaphore, count);
    @memset(image_available_semaphores, null);
    errdefer {
        for (image_available_semaphores) |maybe_semaphore| {
            if (maybe_semaphore) |semaphore| {
                c.vkDestroySemaphore(device, semaphore, null);
            }
        }
        allocator.free(image_available_semaphores);
    }

    var render_finished_semaphores = try allocator.alloc(c.VkSemaphore, count);
    @memset(render_finished_semaphores, null);
    errdefer {
        for (render_finished_semaphores) |maybe_semaphore| {
            if (maybe_semaphore) |semaphore| {
                c.vkDestroySemaphore(device, semaphore, null);
            }
        }
        allocator.free(render_finished_semaphores);
    }

    var in_flight_fences = try allocator.alloc(c.VkFence, count);
    @memset(in_flight_fences, null);
    errdefer {
        for (in_flight_fences) |maybe_fence| {
            if (maybe_fence) |fence| {
                c.vkDestroyFence(device, fence, null);
            }
        }
        allocator.free(in_flight_fences);
    }

    const semaphore_info = std.mem.zeroInit(c.VkSemaphoreCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    });
    const fence_info = std.mem.zeroInit(c.VkFenceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    });
    for (0..count) |index| {
        if (c.vkCreateSemaphore(
            device,
            &semaphore_info,
            null,
            &image_available_semaphores[index],
        ) != c.VK_SUCCESS) {
            return error.VkCreateSemaphoreFailed;
        }
        if (c.vkCreateSemaphore(
            device,
            &semaphore_info,
            null,
            &render_finished_semaphores[index],
        ) != c.VK_SUCCESS) {
            return error.VkCreateSemaphoreFailed;
        }

        if (c.vkCreateFence(device, &fence_info, null, &in_flight_fences[index]) != c.VK_SUCCESS) {
            return error.VkCreateFenceFailed;
        }
    }

    return .{
        .command_buffers = command_buffers,
        .image_available_semaphores = image_available_semaphores,
        .render_finished_semaphores = render_finished_semaphores,
        .in_flight_fences = in_flight_fences,
        .allocator = allocator,
        .device = device,
        .command_pool = command_pool,
    };
}

pub fn deinit(self: Self) void {
    std.log.info("Destroying command buffer", .{});

    for (self.in_flight_fences) |fence| {
        c.vkDestroyFence(self.device, fence, null);
    }
    self.allocator.free(self.in_flight_fences);

    for (self.render_finished_semaphores) |semaphore| {
        c.vkDestroySemaphore(self.device, semaphore, null);
    }
    self.allocator.free(self.render_finished_semaphores);

    for (self.image_available_semaphores) |semaphore| {
        c.vkDestroySemaphore(self.device, semaphore, null);
    }
    self.allocator.free(self.image_available_semaphores);

    c.vkFreeCommandBuffers(
        self.device,
        self.command_pool,
        @intCast(self.command_buffers.len),
        self.command_buffers.ptr,
    );
    self.allocator.free(self.command_buffers);
}
