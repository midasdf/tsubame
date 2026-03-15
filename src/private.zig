const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;

/// Create an ephemeral (private) WebView that doesn't persist cookies,
/// history, or cache. Uses WebKit's ephemeral web context.
pub fn createPrivateWebView() *c.GtkWidget {
    const ephemeral_ctx = c.webkit_web_context_new_ephemeral();
    const content_manager = c.webkit_user_content_manager_new();

    const webview = c.g_object_new(
        c.webkit_web_view_get_type(),
        "web-context",
        @as(?*anyopaque, @ptrCast(@alignCast(ephemeral_ctx))),
        "user-content-manager",
        @as(?*anyopaque, @ptrCast(@alignCast(content_manager))),
        @as(?*anyopaque, null),
    );

    return @ptrCast(@alignCast(webview));
}

/// Check if a WebView is in private mode
pub fn isPrivate(webview: *c.GtkWidget) bool {
    const ctx = c.webkit_web_view_get_context(ch.WEBKIT_WEB_VIEW(webview));
    return c.webkit_web_context_is_ephemeral(ctx) != 0;
}
