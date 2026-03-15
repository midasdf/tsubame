const std = @import("std");

pub const c = @cImport({
    @cInclude("gtk/gtk.h");
    @cInclude("glib-unix.h");
    @cInclude("webkit2/webkit2.h");
    @cInclude("sqlite3.h");
});

// --- Type cast helpers ---
// GTK uses C macros for type casting (GTK_WINDOW, GTK_CONTAINER, etc.)
// These are not available via @cImport, so we provide Zig equivalents.

pub fn GTK_WINDOW(ptr: anytype) *c.GtkWindow {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_CONTAINER(ptr: anytype) *c.GtkContainer {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_BOX(ptr: anytype) *c.GtkBox {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_ENTRY(ptr: anytype) *c.GtkEntry {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_LABEL(ptr: anytype) *c.GtkLabel {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_BUTTON(ptr: anytype) *c.GtkButton {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_STACK(ptr: anytype) *c.GtkStack {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_WIDGET(ptr: anytype) *c.GtkWidget {
    return @ptrCast(@alignCast(ptr));
}

pub fn GTK_EDITABLE(ptr: anytype) *c.GtkEditable {
    return @ptrCast(@alignCast(ptr));
}

pub fn WEBKIT_WEB_VIEW(ptr: anytype) *c.WebKitWebView {
    return @ptrCast(@alignCast(ptr));
}

pub fn WEBKIT_SETTINGS(ptr: anytype) *c.WebKitSettings {
    return @ptrCast(@alignCast(ptr));
}

// --- Signal connect helper ---
// g_signal_connect is a C macro that expands to g_signal_connect_data.

pub fn connectSignal(
    instance: anytype,
    signal_name: [*:0]const u8,
    callback: anytype,
    data: anytype,
) void {
    _ = c.g_signal_connect_data(
        @as(*c.GObject, @ptrCast(@alignCast(instance))),
        signal_name,
        @ptrCast(callback),
        @ptrCast(@alignCast(data)),
        null,
        0,
    );
}

pub fn connectSignalNoData(
    instance: anytype,
    signal_name: [*:0]const u8,
    callback: anytype,
) void {
    _ = c.g_signal_connect_data(
        @as(*c.GObject, @ptrCast(@alignCast(instance))),
        signal_name,
        @ptrCast(callback),
        null,
        null,
        0,
    );
}
