const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;

pub fn findInPage(webview: *c.GtkWidget, text: [*:0]const u8, forward: bool) void {
    const controller = c.webkit_web_view_get_find_controller(ch.WEBKIT_WEB_VIEW(webview));
    const span = std.mem.span(text);

    if (span.len == 0) {
        c.webkit_find_controller_search_finish(controller);
        return;
    }

    var flags: u32 = c.WEBKIT_FIND_OPTIONS_CASE_INSENSITIVE | c.WEBKIT_FIND_OPTIONS_WRAP_AROUND;
    if (!forward) flags |= c.WEBKIT_FIND_OPTIONS_BACKWARDS;

    c.webkit_find_controller_search(controller, text, flags, 0);
}

pub fn findNext(webview: *c.GtkWidget) void {
    const controller = c.webkit_web_view_get_find_controller(ch.WEBKIT_WEB_VIEW(webview));
    c.webkit_find_controller_search_next(controller);
}

pub fn findPrev(webview: *c.GtkWidget) void {
    const controller = c.webkit_web_view_get_find_controller(ch.WEBKIT_WEB_VIEW(webview));
    c.webkit_find_controller_search_previous(controller);
}

pub fn clearFind(webview: *c.GtkWidget) void {
    const controller = c.webkit_web_view_get_find_controller(ch.WEBKIT_WEB_VIEW(webview));
    c.webkit_find_controller_search_finish(controller);
}
