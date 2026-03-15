const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");
const config = @import("config.zig");

const USER_AGENT = "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

var g_low_memory: bool = false;

pub fn setupContext(db: *storage.Database) void {
    const ctx = c.webkit_web_context_get_default();

    // Check if low memory mode is enabled (auto-detect from system RAM)
    g_low_memory = config.getBool(db, "low_memory") orelse detectLowMemory();

    if (g_low_memory) {
        // Use document viewer cache model — minimal memory/disk cache
        c.webkit_web_context_set_cache_model(
            ctx,
            c.WEBKIT_CACHE_MODEL_DOCUMENT_VIEWER,
        );
    }

    // Setup cookies
    const data_dir = storage.getDataDir();
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

fn detectLowMemory() bool {
    // Read /proc/meminfo to detect total RAM
    const file = std.fs.cwd().openFile("/proc/meminfo", .{}) catch return false;
    defer file.close();
    var buf: [256]u8 = undefined;
    const len = file.readAll(&buf) catch return false;
    const content = buf[0..len];

    // Parse "MemTotal:     XXXX kB"
    if (std.mem.indexOf(u8, content, "MemTotal:")) |pos| {
        const after = std.mem.trimLeft(u8, content[pos + 9 ..], " ");
        if (std.mem.indexOfScalar(u8, after, ' ')) |space| {
            const kb_str = after[0..space];
            const kb = std.fmt.parseInt(u64, kb_str, 10) catch return false;
            const mb = kb / 1024;
            return mb <= 1024; // Low memory if <= 1GB
        }
    }
    return false;
}

pub fn createWebView() *c.GtkWidget {
    const settings = c.webkit_settings_new();
    c.webkit_settings_set_user_agent(ch.WEBKIT_SETTINGS(settings), USER_AGENT);

    if (g_low_memory) {
        // Disable hardware acceleration (saves GPU memory, uses less RAM on fbdev)
        c.webkit_settings_set_hardware_acceleration_policy(
            ch.WEBKIT_SETTINGS(settings),
            c.WEBKIT_HARDWARE_ACCELERATION_POLICY_NEVER,
        );

        // Reduce memory usage
        c.webkit_settings_set_enable_smooth_scrolling(ch.WEBKIT_SETTINGS(settings), 0);
        c.webkit_settings_set_enable_page_cache(ch.WEBKIT_SETTINGS(settings), 0);
    }

    const webview = c.webkit_web_view_new_with_settings(ch.WEBKIT_SETTINGS(settings));
    return @ptrCast(@alignCast(webview));
}

pub fn isLowMemory() bool {
    return g_low_memory;
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

pub fn runJavaScript(webview: *c.GtkWidget, script: [*:0]const u8) void {
    c.webkit_web_view_run_javascript(
        ch.WEBKIT_WEB_VIEW(webview),
        script,
        null,
        null,
        null,
    );
}
