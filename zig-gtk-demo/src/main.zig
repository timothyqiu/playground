const std = @import("std");
const c = @import("c.zig");
const gtk = @import("gtk.zig");

pub fn main() !u8 {
    const app = c.gtk_application_new(null, c.G_APPLICATION_DEFAULT_FLAGS);
    defer c.g_object_unref(app);

    _ = gtk.signalConnect(app, "activate", @ptrCast(&activate), null);

    const status = c.g_application_run(@ptrCast(app), 0, null);
    return @intCast(status);
}

fn activate(app: *c.GtkApplication, _: c.gpointer) callconv(.C) void {
    var builder = gtk.Builder.initFromString(@embedFile("builder.ui"));
    defer builder.deinit();

    const window = builder.getObject(c.GtkWindow, "window").?;
    c.gtk_window_set_application(window, app);

    const quit = builder.getObject(c.GtkButton, "quit");
    _ = gtk.signalConnectSwapped(quit, "clicked", @ptrCast(&c.gtk_window_destroy), window);

    gtk.windowPresent(window);
}
