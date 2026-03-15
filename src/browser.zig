const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");

const USER_AGENT = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

pub fn createWebView() *c.GtkWidget {
    const settings = c.webkit_settings_new();
    c.webkit_settings_set_user_agent(ch.WEBKIT_SETTINGS(settings), USER_AGENT);
    _ = c.g_object_set_data(
        @as(*c.GObject, @ptrCast(@alignCast(settings))),
        "enable-javascript",
        @as(?*anyopaque, @ptrFromInt(1)),
    );

    const webview = c.webkit_web_view_new_with_settings(ch.WEBKIT_SETTINGS(settings));
    return @ptrCast(@alignCast(webview));
}

pub fn loadUri(webview: *c.GtkWidget, uri: [*:0]const u8) void {
    c.webkit_web_view_load_uri(ch.WEBKIT_WEB_VIEW(webview), uri);
}

pub fn goBack(webview: *c.GtkWidget) void {
    c.webkit_web_view_go_back(ch.WEBKIT_WEB_VIEW(webview));
}

pub fn goForward(webview: *c.GtkWidget) void {
    c.webkit_web_view_go_forward(ch.WEBKIT_WEB_VIEW(webview));
}

pub fn reload(webview: *c.GtkWidget) void {
    c.webkit_web_view_reload(ch.WEBKIT_WEB_VIEW(webview));
}

pub fn stopLoading(webview: *c.GtkWidget) void {
    c.webkit_web_view_stop_loading(ch.WEBKIT_WEB_VIEW(webview));
}

pub fn getUri(webview: *c.GtkWidget) ?[*:0]const u8 {
    return c.webkit_web_view_get_uri(ch.WEBKIT_WEB_VIEW(webview));
}

pub fn getTitle(webview: *c.GtkWidget) ?[*:0]const u8 {
    return c.webkit_web_view_get_title(ch.WEBKIT_WEB_VIEW(webview));
}

pub fn setupCookies() void {
    const data_dir = storage.getDataDir();
    const ctx = c.webkit_web_context_get_default();
    const cookie_manager = c.webkit_web_context_get_cookie_manager(ctx);

    var path_buf: [512]u8 = undefined;
    const cookie_path = std.fmt.bufPrint(&path_buf, "{s}/cookies.sqlite", .{data_dir}) catch return;
    path_buf[cookie_path.len] = 0;

    c.webkit_cookie_manager_set_persistent_storage(
        cookie_manager,
        @ptrCast(path_buf[0..cookie_path.len :0]),
        c.WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE,
    );
    c.webkit_cookie_manager_set_accept_policy(
        cookie_manager,
        c.WEBKIT_COOKIE_POLICY_ACCEPT_NO_THIRD_PARTY,
    );
}

pub fn runJavaScript(webview: *c.GtkWidget, script: [*:0]const u8) void {
    c.webkit_web_view_run_javascript(
        ch.WEBKIT_WEB_VIEW(webview),
        script,
        null,
        null,
        null,
    );
}
