const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");

/// Load user scripts from ~/.local/share/tsubame/scripts/*.js
/// and inject them into WebViews via WebKitUserContentManager.
/// Scripts are injected at document-end by default.

var g_scripts: [16]?*c.WebKitUserScript = .{null} ** 16;
var g_script_count: usize = 0;

pub fn loadScripts() void {
    const data_dir = storage.getDataDir();
    var path_buf: [512]u8 = undefined;
    const scripts_dir = std.fmt.bufPrint(&path_buf, "{s}/scripts", .{data_dir}) catch return;

    // Create scripts directory if it doesn't exist
    std.fs.cwd().makePath(scripts_dir) catch {};

    var dir = std.fs.cwd().openDir(scripts_dir, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (g_script_count >= 16) break;

        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".js")) continue;

        // Read the script file
        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();

        var buf: [65536]u8 = undefined; // 64KB max per script
        const len = file.readAll(&buf) catch continue;
        if (len == 0) continue;
        buf[len] = 0;

        // Create WebKitUserScript
        const script = c.webkit_user_script_new(
            &buf,
            c.WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES,
            c.WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_END,
            null, // allow_list
            null, // block_list
        );

        if (script) |s| {
            g_scripts[g_script_count] = s;
            g_script_count += 1;
        }
    }
}

/// Apply loaded user scripts to a WebView
pub fn applyToWebView(webview: *c.GtkWidget) void {
    const content_manager = c.webkit_web_view_get_user_content_manager(
        ch.WEBKIT_WEB_VIEW(webview),
    );

    for (g_scripts[0..g_script_count]) |maybe_script| {
        if (maybe_script) |script| {
            c.webkit_user_content_manager_add_script(content_manager, script);
        }
    }
}
