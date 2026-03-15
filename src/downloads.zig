const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");

var g_dl_db: *storage.Database = undefined;
var g_dl_bar: *c.GtkWidget = undefined;
var g_dl_label: *c.GtkWidget = undefined;

pub fn setup(db: *storage.Database, download_bar: *c.GtkWidget, download_label: *c.GtkWidget) void {
    g_dl_db = db;
    g_dl_bar = download_bar;
    g_dl_label = download_label;

    const ctx = c.webkit_web_context_get_default();
    ch.connectSignalNoData(ctx, "download-started", &onDownloadStarted);
}

fn onDownloadStarted(_: [*c]c.WebKitWebContext, download: [*c]c.WebKitDownload, _: ?*anyopaque) callconv(.c) void {
    ch.connectSignalNoData(download, "decide-destination", &onDecideDestination);
    ch.connectSignalNoData(download, "finished", &onDownloadFinished);
    ch.connectSignalNoData(download, "failed", &onDownloadFailed);

    c.gtk_label_set_text(ch.GTK_LABEL(g_dl_label), "Downloading...");
    c.gtk_widget_show_all(g_dl_bar);
}

fn onDecideDestination(download: [*c]c.WebKitDownload, suggested: [*c]const u8, _: ?*anyopaque) callconv(.c) c_int {
    const home = std.posix.getenv("HOME") orelse return 0;
    const filename = std.mem.span(suggested);

    var buf: [1024]u8 = undefined;
    const dest = std.fmt.bufPrintZ(&buf, "file://{s}/Downloads/{s}", .{ home, filename }) catch return 0;
    c.webkit_download_set_destination(download, dest.ptr);

    c.gtk_label_set_text(ch.GTK_LABEL(g_dl_label), suggested);

    // Record in DB
    const stmt = g_dl_db.prepare(
        "INSERT INTO downloads (url, filepath, status, started_at) VALUES (?, ?, 'in_progress', ?)",
    ) catch return 1;
    defer _ = c.sqlite3_finalize(stmt);
    const request = c.webkit_download_get_request(download);
    _ = c.sqlite3_bind_text(stmt, 1, c.webkit_uri_request_get_uri(request), -1, null);
    var path_buf: [1024]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buf, "{s}/Downloads/{s}", .{ home, filename }) catch return 1;
    _ = c.sqlite3_bind_text(stmt, 2, path.ptr, -1, null);
    _ = c.sqlite3_bind_int64(stmt, 3, std.time.timestamp());
    _ = c.sqlite3_step(stmt);

    return 1;
}

fn onDownloadFinished(_: [*c]c.WebKitDownload, _: ?*anyopaque) callconv(.c) void {
    c.gtk_label_set_text(ch.GTK_LABEL(g_dl_label), "Download complete!");
    _ = c.g_timeout_add(5000, &hideBar, null);
}

fn onDownloadFailed(_: [*c]c.WebKitDownload, _: ?*anyopaque) callconv(.c) void {
    c.gtk_label_set_text(ch.GTK_LABEL(g_dl_label), "Download failed");
    _ = c.g_timeout_add(5000, &hideBar, null);
}

fn hideBar(_: ?*anyopaque) callconv(.c) c_int {
    c.gtk_widget_hide(g_dl_bar);
    return 0;
}
