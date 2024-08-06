const std = @import("std");
const c = @import("c.zig");

const gchar = c.gchar;
const gulong = c.gulong;
const gpointer = c.gpointer;

pub fn signalConnect(
    instance: gpointer,
    detailed_signal: [*c]const gchar,
    c_handler: c.GCallback,
    data: gpointer,
) gulong {
    const ret = c.g_signal_connect_data(
        instance,
        detailed_signal,
        c_handler,
        data,
        null,
        0,
    );
    std.debug.assert(ret > 0);
    return ret;
}

pub fn signalConnectSwapped(
    instance: gpointer,
    detailed_signal: [*c]const gchar,
    c_handler: c.GCallback,
    data: gpointer,
) gulong {
    const ret = c.g_signal_connect_data(
        instance,
        detailed_signal,
        c_handler,
        data,
        null,
        c.G_CONNECT_SWAPPED,
    );
    std.debug.assert(ret > 0);
    return ret;
}

pub fn applicationWindowNew(app: *c.GtkApplication) *c.GtkApplicationWindow {
    return @ptrCast(c.gtk_application_window_new(app));
}

pub fn windowPresent(window: anytype) void {
    switch (@typeInfo(@TypeOf(window))) {
        .Pointer => |info| {
            switch (info.child) {
                c.GtkApplicationWindow,
                c.GtkWindow,
                => c.gtk_window_present(@ptrCast(window)),

                else => @compileError("`window` should point to a GtkWindow derived type"),
            }
        },

        else => @compileError("`window` should be a pointer"),
    }
}

pub const Builder = struct {
    builder: *c.GtkBuilder,

    pub fn initFromString(string: []const u8) Builder {
        const builder = c.gtk_builder_new_from_string(
            string.ptr,
            @intCast(string.len),
        ) orelse unreachable; // Aborts on failure.
        return .{ .builder = builder };
    }

    pub fn deinit(self: Builder) void {
        c.g_object_unref(self.builder);
    }

    pub fn getObject(self: *Builder, comptime T: type, name: [:0]const u8) ?*T {
        if (c.gtk_builder_get_object(self.builder, name.ptr)) |obj| {
            return @ptrCast(obj);
        }
        return null;
    }
};
