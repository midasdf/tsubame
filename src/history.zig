const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");

pub fn recordVisit(db: *storage.Database, url: [*:0]const u8, title: ?[*:0]const u8) void {
    const stmt = db.prepare(
        "INSERT INTO history (url, title, visited_at) VALUES (?, ?, ?)",
    ) catch return;
    defer _ = c.sqlite3_finalize(stmt);

    _ = c.sqlite3_bind_text(stmt, 1, url, -1, null);
    if (title) |t| {
        _ = c.sqlite3_bind_text(stmt, 2, t, -1, null);
    } else {
        _ = c.sqlite3_bind_null(stmt, 2);
    }
    _ = c.sqlite3_bind_int64(stmt, 3, std.time.timestamp());
    _ = c.sqlite3_step(stmt);
}

pub fn generateHistoryPage(db: *storage.Database, allocator: std.mem.Allocator) ?[]const u8 {
    const stmt = db.prepare(
        "SELECT url, title, visited_at FROM history ORDER BY visited_at DESC LIMIT 200",
    ) catch return null;
    defer _ = c.sqlite3_finalize(stmt);

    var html = std.ArrayListUnmanaged(u8).empty;
    const w = html.writer(allocator);

    w.writeAll(
        \\<!DOCTYPE html><html><head><meta charset="utf-8">
        \\<title>History - Tsubame</title>
        \\<style>
        \\body{font-family:sans-serif;margin:20px;background:#1a1a2e;color:#e0e0e0}
        \\h1{color:#53a8b6}
        \\a{color:#53a8b6;text-decoration:none}
        \\a:hover{text-decoration:underline}
        \\.entry{padding:8px 0;border-bottom:1px solid #333}
        \\.url{color:#888;font-size:0.85em}
        \\</style></head><body><h1>History</h1>
    ) catch return null;

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const url = c.sqlite3_column_text(stmt, 0);
        const title = c.sqlite3_column_text(stmt, 1);

        if (url) |u| {
            const u_span = std.mem.span(u);
            const t_span = if (title) |tt| std.mem.span(tt) else u_span;
            w.print(
                \\<div class="entry"><a href="{s}">{s}</a><br><span class="url">{s}</span></div>
            , .{ u_span, t_span, u_span }) catch continue;
        }
    }

    w.writeAll("</body></html>") catch return null;
    return html.toOwnedSlice(allocator) catch null;
}
