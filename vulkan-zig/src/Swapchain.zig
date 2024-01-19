const std = @import("std");
const c = @import("c.zig");
const Allocator = std.mem.Allocator;

const Options = struct {
    surface_format: c.VkSurfaceFormatKHR,
    present_mode: c.VkPresentModeKHR,
    extent: c.VkExtent2D,
    min_image_count: u32,
    pre_transform: c.VkSurfaceTransformFlagBitsKHR,
};

const Self = @This();

allocator: Allocator,
device: c.VkDevice,
swapchain: c.VkSwapchainKHR,
image_format: c.VkFormat,
extent: c.VkExtent2D,

images: []c.VkImage,
image_views: []c.VkImageView,
framebuffers: []c.VkFramebuffer,

render_pass: c.VkRenderPass,

pub fn init(
    allocator: Allocator,
    physical_device: c.VkPhysicalDevice,
    window: *c.GLFWwindow,
    device: c.VkDevice,
    surface: c.VkSurfaceKHR,
    graphics_family_index: u32,
    present_family_index: u32,
) !Self {
    std.log.info("Creating swapchain", .{});

    var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    if (c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
        physical_device,
        surface,
        &capabilities,
    ) != c.VK_SUCCESS) {
        return error.VkGetPhysicalDeviceSurfaceCapabilitiesKHRFailed;
    }

    var format_count: u32 = undefined;
    if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(
        physical_device,
        surface,
        &format_count,
        null,
    ) != c.VK_SUCCESS) {
        return error.VkGetPhysicalDeviceSurfaceFormatsKHRFailed;
    }

    var formats = try allocator.alloc(c.VkSurfaceFormatKHR, format_count);
    defer allocator.free(formats);
    switch (c.vkGetPhysicalDeviceSurfaceFormatsKHR(
        physical_device,
        surface,
        &format_count,
        formats.ptr,
    )) {
        c.VK_SUCCESS, c.VK_INCOMPLETE => {},
        else => return error.VkGetPhysicalDeviceSurfaceFormatsKHRFailed,
    }

    var present_mode_count: u32 = undefined;
    if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(
        physical_device,
        surface,
        &present_mode_count,
        null,
    ) != c.VK_SUCCESS) {
        return error.VkGetPhysicalDeviceSurfacePresentModesKHRFailed;
    }

    var present_modes = try allocator.alloc(c.VkPresentModeKHR, present_mode_count);
    defer allocator.free(present_modes);
    switch (c.vkGetPhysicalDeviceSurfacePresentModesKHR(
        physical_device,
        surface,
        &present_mode_count,
        present_modes.ptr,
    )) {
        c.VK_SUCCESS, c.VK_INCOMPLETE => {},
        else => return error.VkGetPhysicalDeviceSurfacePresentModesKHRFailed,
    }

    const min_image_count = blk: {
        var count: u32 = capabilities.minImageCount + 1;
        if (capabilities.maxImageCount > 0 and count > capabilities.maxImageCount) {
            count = capabilities.maxImageCount;
        }
        break :blk count;
    };

    const surface_format = blk: {
        for (formats) |format| {
            if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                break :blk format;
            }
        }
        break :blk formats[0];
    };

    const present_mode = blk: {
        for (present_modes) |present_mode| {
            if (present_mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
                break :blk present_mode;
            }
        }
        break :blk c.VK_PRESENT_MODE_FIFO_KHR;
    };

    const extent = blk: {
        if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
            break :blk capabilities.currentExtent;
        }

        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetFramebufferSize(window, &width, &height);

        break :blk c.VkExtent2D{
            .width = std.math.clamp(
                @as(u32, @intCast(width)),
                capabilities.minImageExtent.width,
                capabilities.maxImageExtent.width,
            ),
            .height = std.math.clamp(
                @as(u32, @intCast(height)),
                capabilities.minImageExtent.height,
                capabilities.maxImageExtent.height,
            ),
        };
    };

    // Create Swapchain

    var create_info = std.mem.zeroInit(c.VkSwapchainCreateInfoKHR, .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = min_image_count,
        .imageFormat = surface_format.format,
        .imageColorSpace = surface_format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .preTransform = capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = present_mode,
        .clipped = c.VK_TRUE,
    });

    if (graphics_family_index != present_family_index) {
        const queue_family_indices = [_]u32{ graphics_family_index, present_family_index };
        create_info.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        create_info.queueFamilyIndexCount = 2;
        create_info.pQueueFamilyIndices = &queue_family_indices;
    } else {
        create_info.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
    }

    var swapchain: c.VkSwapchainKHR = undefined;
    switch (c.vkCreateSwapchainKHR(device, &create_info, null, &swapchain)) {
        c.VK_SUCCESS => {},
        else => |e| {
            std.log.err("Failed to create swapchain: {}", .{e});
            return error.VkCreateSwapchainKHRFailed;
        },
    }
    errdefer c.vkDestroySwapchainKHR(device, swapchain, null);

    // Create render pass

    const color_attachment = std.mem.zeroInit(c.VkAttachmentDescription, .{
        .format = surface_format.format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    });
    const color_attachment_ref = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const subpass = std.mem.zeroInit(c.VkSubpassDescription, .{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,
    });

    const render_pass_info = std.mem.zeroInit(c.VkRenderPassCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
    });

    var render_pass: c.VkRenderPass = undefined;
    if (c.vkCreateRenderPass(device, &render_pass_info, null, &render_pass) != c.VK_SUCCESS) {
        return error.VkCreateRenderPassFailed;
    }
    errdefer c.vkDestroyRenderPass(device, render_pass, null);

    // Create image views and framebuffers

    var image_count: u32 = undefined;
    if (c.vkGetSwapchainImagesKHR(device, swapchain, &image_count, null) != c.VK_SUCCESS) {
        return error.VkGetSwapchainImagesKHRFailed;
    }
    var images = try allocator.alloc(c.VkImage, image_count);
    errdefer allocator.free(images);
    switch (c.vkGetSwapchainImagesKHR(device, swapchain, &image_count, images.ptr)) {
        c.VK_SUCCESS, c.VK_INCOMPLETE => {},
        else => return error.VkGetSwapchainImagesKHRFailed,
    }

    var image_views = try allocator.alloc(c.VkImageView, image_count);
    @memset(image_views, null);
    errdefer {
        for (image_views) |maybe_view| {
            if (maybe_view) |view| {
                c.vkDestroyImageView(device, view, null);
            }
        }
        allocator.free(image_views);
    }
    var framebuffers = try allocator.alloc(c.VkFramebuffer, image_count);
    @memset(image_views, null);
    errdefer {
        for (framebuffers) |maybe_framebuffer| {
            if (maybe_framebuffer) |framebuffer| {
                c.vkDestroyFramebuffer(device, framebuffer, null);
            }
        }
        allocator.free(framebuffers);
    }

    for (images, image_views, framebuffers) |image, *image_view, *framebuffer| {
        const image_view_create_info = std.mem.zeroInit(c.VkImageViewCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = surface_format.format,
            .components = .{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        });
        if (c.vkCreateImageView(device, &image_view_create_info, null, image_view) != c.VK_SUCCESS) {
            return error.VkCreateImageViewFailed;
        }

        const framebuffer_info = std.mem.zeroInit(c.VkFramebufferCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = render_pass,
            .attachmentCount = 1,
            .pAttachments = image_view,
            .width = extent.width,
            .height = extent.height,
            .layers = 1,
        });
        if (c.vkCreateFramebuffer(device, &framebuffer_info, null, framebuffer) != c.VK_SUCCESS) {
            return error.VkCreateFramebufferFailed;
        }
    }

    return .{
        .allocator = allocator,
        .swapchain = swapchain,
        .image_format = surface_format.format,
        .extent = extent,
        .images = images,
        .image_views = image_views,
        .framebuffers = framebuffers,
        .device = device,
        .render_pass = render_pass,
    };
}

pub fn deinit(self: Self) void {
    std.log.info("Destroying swapchain", .{});

    c.vkDestroyRenderPass(self.device, self.render_pass, null);

    for (self.framebuffers) |framebuffer| {
        c.vkDestroyFramebuffer(self.device, framebuffer, null);
    }
    self.allocator.free(self.framebuffers);

    for (self.image_views) |image_view| {
        c.vkDestroyImageView(self.device, image_view, null);
    }
    self.allocator.free(self.image_views);

    c.vkDestroySwapchainKHR(self.device, self.swapchain, null);
    self.allocator.free(self.images);
}
