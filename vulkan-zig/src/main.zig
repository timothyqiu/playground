const std = @import("std");
const builtin = @import("builtin");
const c = @cImport(
    @cInclude("vulkan/vulkan.h"),
);

fn ApiFuncType(comptime name: [:0]const u8) type {
    return std.meta.Child(@field(c, "PFN_" ++ name));
}

fn getLibraryFunc(library: *std.DynLib, comptime name: [:0]const u8) !ApiFuncType(name) {
    return library.lookup(ApiFuncType(name), name) orelse error.AddrNotFound;
}

fn getVulkanCoreFunc(comptime name: [:0]const u8, proc_addr: anytype, handle: anytype) ApiFuncType(name) {
    return @ptrCast(proc_addr(handle, name).?);
}

const Entry = struct {
    const Self = @This();
    const LibraryNames = switch (builtin.os.tag) {
        .windows => [_][]const u8{
            "vulkan-1.dll",
        },
        .macos, .ios, .tvos, .watchos => [_][]const u8{
            "libvulkan.dylib",
            "libvulkan.1.dylib",
            "libMoltenVK.dylib",
        },
        .linux => [_][]const u8{
            "libvulkan.so.1",
            "libvulkan.so",
        },
        else => @compileError("Unsupported OS"),
    };

    handle: std.DynLib,
    get_instance_proc_addr: std.meta.Child(c.PFN_vkGetInstanceProcAddr),
    create_instance: std.meta.Child(c.PFN_vkCreateInstance),

    fn init() !Self {
        var library = try loadLibrary();
        errdefer library.close();

        const get_instance_proc_addr = try getLibraryFunc(&library, "vkGetInstanceProcAddr");

        return .{
            .handle = library,
            .get_instance_proc_addr = get_instance_proc_addr,
            .create_instance = getVulkanCoreFunc("vkCreateInstance", get_instance_proc_addr, null),
        };
    }

    fn deinit(self: *Self) void {
        self.handle.close();
    }

    fn loadLibrary() !std.DynLib {
        for (LibraryNames) |library_name| {
            return std.DynLib.open(library_name) catch continue;
        }
        return error.LibraryNotFound;
    }
};

const Instance = struct {
    const Self = @This();

    handle: c.VkInstance,
    destroy_instance: std.meta.Child(c.PFN_vkDestroyInstance),
    enumerate_physical_devices: std.meta.Child(c.PFN_vkEnumeratePhysicalDevices),
    get_physical_device_queue_family_properties: std.meta.Child(c.PFN_vkGetPhysicalDeviceQueueFamilyProperties),
    create_device: std.meta.Child(c.PFN_vkCreateDevice),
    get_device_proc_addr: std.meta.Child(c.PFN_vkGetDeviceProcAddr),
    allocation_callbacks: ?*c.VkAllocationCallbacks,

    fn init(entry: Entry, allocation_callbacks: ?*c.VkAllocationCallbacks) !Self {
        const info = std.mem.zeroInit(c.VkInstanceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        });

        var instance: c.VkInstance = undefined;
        return switch (entry.create_instance(&info, allocation_callbacks, &instance)) {
            c.VK_SUCCESS => .{
                .handle = instance,
                .allocation_callbacks = allocation_callbacks,
                .destroy_instance = getVulkanCoreFunc("vkDestroyInstance", entry.get_instance_proc_addr, instance),
                .enumerate_physical_devices = getVulkanCoreFunc("vkEnumeratePhysicalDevices", entry.get_instance_proc_addr, instance),
                .get_physical_device_queue_family_properties = getVulkanCoreFunc("vkGetPhysicalDeviceQueueFamilyProperties", entry.get_instance_proc_addr, instance),
                .create_device = getVulkanCoreFunc("vkCreateDevice", entry.get_instance_proc_addr, instance),
                .get_device_proc_addr = getVulkanCoreFunc("vkGetDeviceProcAddr", entry.get_instance_proc_addr, instance),
            },
            c.VK_ERROR_OUT_OF_HOST_MEMORY => error.VulkanOutOfHostMemory,
            c.VK_ERROR_OUT_OF_DEVICE_MEMORY => error.VulkanOutOfDeviceMemory,
            c.VK_ERROR_INITIALIZATION_FAILED => error.VulkanInitializationFailed,
            c.VK_ERROR_LAYER_NOT_PRESENT => error.VulkanLayerNotPresent,
            c.VK_ERROR_EXTENSION_NOT_PRESENT => error.VulkanExtensionNotPresent,
            c.VK_ERROR_INCOMPATIBLE_DRIVER => error.VulkanIncompatibleDriver,
            else => unreachable,
        };
    }

    fn deinit(self: Self) void {
        self.destroy_instance(self.handle, self.allocation_callbacks);
    }

    fn enumeratePhysicalDevices(self: Self, allocator: std.mem.Allocator) ![]c.VkPhysicalDevice {
        var count: u32 = undefined;

        switch (self.enumerate_physical_devices(self.handle, &count, null)) {
            c.VK_SUCCESS => {},
            c.VK_INCOMPLETE => unreachable,
            c.VK_ERROR_OUT_OF_HOST_MEMORY => return error.VulkanOutOfHostMemory,
            c.VK_ERROR_OUT_OF_DEVICE_MEMORY => return error.VulkanOutOfDeviceMemory,
            c.VK_ERROR_INITIALIZATION_FAILED => return error.VulkanInitializationFailed,
            else => unreachable,
        }

        var physical_devices = try allocator.alloc(c.VkPhysicalDevice, count);
        errdefer allocator.free(physical_devices);

        return switch (self.enumerate_physical_devices(self.handle, &count, physical_devices.ptr)) {
            c.VK_SUCCESS, c.VK_INCOMPLETE => physical_devices,
            c.VK_ERROR_OUT_OF_HOST_MEMORY => error.VulkanOutOfHostMemory,
            c.VK_ERROR_OUT_OF_DEVICE_MEMORY => error.VulkanOutOfDeviceMemory,
            c.VK_ERROR_INITIALIZATION_FAILED => error.VulkanInitializationFailed,
            else => unreachable,
        };
    }

    fn selectQueueFamily(self: Self, physical_devices: []c.VkPhysicalDevice, mask: c.VkQueueFlags, allocator: std.mem.Allocator) !?QueueFamily {
        var count: u32 = undefined;

        for (physical_devices) |device| {
            self.get_physical_device_queue_family_properties(device, &count, null);

            var queue_family_properties = try allocator.alloc(c.VkQueueFamilyProperties, count);
            defer allocator.free(queue_family_properties);

            self.get_physical_device_queue_family_properties(device, &count, queue_family_properties.ptr);

            for (queue_family_properties, 0..) |queue_family_property, queue_family_index| {
                if (queue_family_property.queueFlags & mask != 0) {
                    return .{
                        .physical_device = device,
                        .queue_family_index = @intCast(queue_family_index),
                    };
                }
            }
        }

        return null;
    }
};

const QueueFamily = struct {
    physical_device: c.VkPhysicalDevice,
    queue_family_index: u32,
};

const Device = struct {
    const Self = @This();

    handle: c.VkDevice,
    destroy_device: std.meta.Child(c.PFN_vkDestroyDevice),
    allocation_callbacks: ?*c.VkAllocationCallbacks,

    fn init(instance: Instance, queue_family: QueueFamily, allocation_callbacks: ?*c.VkAllocationCallbacks) !Device {
        const queue_create_infos = [_]c.VkDeviceQueueCreateInfo{
            std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = queue_family.queue_family_index,
                .queueCount = 1,
                .pQueuePriorities = &[_]f32{1.0},
            }),
        };
        const info = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = queue_create_infos.len,
            .pQueueCreateInfos = &queue_create_infos,
        });

        var device: c.VkDevice = undefined;
        return switch (instance.create_device(queue_family.physical_device, &info, allocation_callbacks, &device)) {
            c.VK_SUCCESS => .{
                .handle = device,
                .allocation_callbacks = allocation_callbacks,
                .destroy_device = getVulkanCoreFunc("vkDestroyDevice", instance.get_device_proc_addr, device),
            },
            c.VK_ERROR_OUT_OF_HOST_MEMORY => error.VulkanOutOfHostMemory,
            c.VK_ERROR_OUT_OF_DEVICE_MEMORY => error.VulkanOutOfDeviceMemory,
            c.VK_ERROR_INITIALIZATION_FAILED => error.VulkanInitializationFailed,
            c.VK_ERROR_EXTENSION_NOT_PRESENT => error.VulkanExtensionNotPresent,
            c.VK_ERROR_FEATURE_NOT_PRESENT => error.VulkanFeatureNotPresent,
            c.VK_ERROR_TOO_MANY_OBJECTS => error.VulkanTooManyObjects,
            c.VK_ERROR_DEVICE_LOST => error.VulkanDeviceLost,
            else => unreachable,
        };
    }

    fn deinit(self: Self) void {
        self.destroy_device(self.handle, self.allocation_callbacks);
    }
};

pub fn main() !void {
    var entry = try Entry.init();
    defer entry.deinit();

    var instance = try Instance.init(entry, null);
    defer instance.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Leaked memory");
    };

    const allocator = gpa.allocator();

    const physical_devices = try instance.enumeratePhysicalDevices(allocator);
    defer allocator.free(physical_devices);
    const queue_family = try instance.selectQueueFamily(physical_devices, c.VK_QUEUE_COMPUTE_BIT, allocator) orelse return error.NoSuitablePhysicalDevice;

    const device = try Device.init(instance, queue_family, null);
    defer device.deinit();

    std.debug.print("Logical device: {}\n", .{device});
}
