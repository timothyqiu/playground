const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const Plug = anyopaque;

const LibPlug = struct {
    lib: ?std.DynLib = null,

    plug_init: *fn () ?*Plug = undefined,
    plug_free: *fn (plug: *Plug) void = undefined,
    plug_update: *fn (plug: *Plug) void = undefined,
    plug_pre_reload: *fn (plug: *Plug) void = undefined,
    plug_post_reload: *fn (plug: *Plug) void = undefined,

    fn reload(self: *LibPlug) !void {
        if (self.lib) |*lib| {
            lib.close();
            self.lib = null;
        }

        var lib = try std.DynLib.open("libplug.so");
        errdefer lib.close();

        var buffer: [128]u8 = undefined;
        inline for (@typeInfo(LibPlug).Struct.fields) |field| {
            if (@typeInfo(field.type) == .Pointer) {
                @memcpy(buffer[0..field.name.len], field.name);
                buffer[field.name.len] = 0;

                @field(self, field.name) = lib.lookup(field.type, buffer[0..field.name.len :0]) orelse return error.SymbolNotFound;
            }
        }

        self.lib = lib;
        std.debug.print("Plugin reloaded\n", .{});
    }

    fn deinit(self: *LibPlug) void {
        var lib = self.lib orelse return;
        lib.close();
    }
};

pub fn main() !void {
    var libplug = LibPlug{};

    try libplug.reload();
    defer libplug.deinit();

    c.SetConfigFlags(c.FLAG_MSAA_4X_HINT);
    c.InitWindow(960, 540, "Musializer");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    c.InitAudioDevice();
    defer c.CloseAudioDevice();

    var plug = libplug.plug_init() orelse return error.FailedPlugInit;
    defer libplug.plug_free(plug);

    while (!c.WindowShouldClose()) {
        if (c.IsKeyPressed(c.KEY_R)) {
            libplug.plug_pre_reload(plug);
            try libplug.reload();
            libplug.plug_post_reload(plug);
        }
        libplug.plug_update(plug);
    }
}
