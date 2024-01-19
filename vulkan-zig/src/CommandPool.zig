const std = @import("std");
const c = @import("c.zig");
const Self = @This();

device: c.VkDevice,
command_pool: c.VkCommandPool,

pub fn init(device: c.VkDevice, queue_family_index: u32) !Self {
    const pool_info = std.mem.zeroInit(c.VkCommandPoolCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = queue_family_index,
    });

    var command_pool: c.VkCommandPool = undefined;
    if (c.vkCreateCommandPool(
        device,
        &pool_info,
        null,
        &command_pool,
    ) != c.VK_SUCCESS) {
        return error.VkCreateCommandPoolFailed;
    }

    return .{
        .device = device,
        .command_pool = command_pool,
    };
}

pub fn deinit(self: Self) void {
    c.vkDestroyCommandPool(self.device, self.command_pool, null);
}
