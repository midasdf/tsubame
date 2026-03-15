const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");
const config = @import("config.zig");

/// Basic ad blocking using WebKit's content filter API.
/// Uses a bundled JSON content filter rule set.
/// Enable/disable via settings: adblock_enabled = true/false

// Minimal content blocker rules targeting common ad domains.
// WebKit Content Blocker format (same as Safari):
// https://webkit.org/blog/3476/content-blockers-first-look/
const default_rules =
    \\[
    \\  {
    \\    "trigger": { "url-filter": ".*", "resource-type": ["script", "image", "style-sheet", "raw"],
    \\      "if-domain": ["*doubleclick.net", "*googlesyndication.com", "*googleadservices.com",
    \\        "*google-analytics.com", "*googletagmanager.com", "*facebook.net",
    \\        "*fbcdn.net", "*adnxs.com", "*adsrvr.org", "*scorecardresearch.com",
    \\        "*amazon-adsystem.com", "*taboola.com", "*outbrain.com", "*criteo.com",
    \\        "*moatads.com", "*quantserve.com", "*rubiconproject.com",
    \\        "*pubmatic.com", "*openx.net", "*casalemedia.com"] },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*doubleclick\\.net" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*googlesyndication\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*googleadservices\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*google-analytics\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*adnxs\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*taboola\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*outbrain\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*criteo\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://[^/]*amazon-adsystem\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "https?://pagead[0-9]*\\.googlesyndication\\.com" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "/ads/" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "/advert" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "/banner[0-9]*\\." },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "/tracking" },
    \\    "action": { "type": "block" }
    \\  },
    \\  {
    \\    "trigger": { "url-filter": "/popup" },
    \\    "action": { "type": "block" }
    \\  }
    \\]
;

var g_content_manager: ?*c.WebKitUserContentManager = null;

pub fn setup(db: *storage.Database) void {
    // Check if adblock is enabled (default: true)
    const enabled = config.getBool(db, "adblock_enabled") orelse true;
    if (!enabled) return;

    const data_dir = storage.getDataDir();
    var path_buf: [512]u8 = undefined;
    const store_path = std.fmt.bufPrintZ(&path_buf, "{s}/content-filters", .{data_dir}) catch return;

    const store = c.webkit_user_content_filter_store_new(store_path.ptr);
    if (store == null) return;

    // Save the filter rules
    const rules_bytes = c.g_bytes_new(default_rules.ptr, default_rules.len);

    c.webkit_user_content_filter_store_save(
        store,
        "tsubame-adblock",
        rules_bytes,
        null, // cancellable
        &onFilterSaved,
        null,
    );

    c.g_bytes_unref(rules_bytes);
}

fn onFilterSaved(source: ?*c.GObject, result: ?*c.GAsyncResult, _: ?*anyopaque) callconv(.c) void {
    var err: ?*c.GError = null;
    const filter = c.webkit_user_content_filter_store_save_finish(
        @ptrCast(@alignCast(source)),
        result,
        &err,
    );

    if (err) |e| {
        std.log.err("adblock filter save error: {s}", .{e.message});
        c.g_error_free(e);
        return;
    }

    if (filter) |f| {
        // Apply to default content manager
        const ctx = c.webkit_web_context_get_default();
        _ = ctx;

        // We need to apply to each WebView's content manager
        // Store the filter globally for use when creating new WebViews
        g_filter = f;
    }
}

var g_filter: ?*c.WebKitUserContentFilter = null;

/// Call this when creating a new WebView to apply adblock filter
pub fn applyToWebView(webview: *c.GtkWidget) void {
    if (g_filter) |filter| {
        const content_manager = c.webkit_web_view_get_user_content_manager(
            ch.WEBKIT_WEB_VIEW(webview),
        );
        c.webkit_user_content_manager_add_filter(content_manager, filter);
    }
}
