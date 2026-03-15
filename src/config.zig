const std = @import("std");
const storage = @import("storage.zig");

/// Simple key=value config file parser (INI-like, no sections)
/// Lines starting with # are comments. Blank lines ignored.
pub fn loadConfigFile(db: *storage.Database) void {
    const data_dir = storage.getDataDir();
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/config", .{data_dir}) catch return;

    const file = std.fs.cwd().openFile(path, .{}) catch return; // No config file = use defaults
    defer file.close();

    var buf: [4096]u8 = undefined;
    const len = file.readAll(&buf) catch return;
    const content = buf[0..len];

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.indexOfScalar(u8, trimmed, '=')) |eq_pos| {
            const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
            const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");
            if (key.len > 0) {
                setSetting(db, key, value);
            }
        }
    }
}

fn setSetting(db: *storage.Database, key: []const u8, value: []const u8) void {
    const ch = @import("c_helpers.zig");
    const c = ch.c;
    const stmt = db.prepare(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
    ) catch return;
    defer _ = c.sqlite3_finalize(stmt);
    _ = c.sqlite3_bind_text(stmt, 1, key.ptr, @intCast(key.len), null);
    _ = c.sqlite3_bind_text(stmt, 2, value.ptr, @intCast(value.len), null);
    _ = c.sqlite3_step(stmt);
}

/// Get a setting as a slice. Caller must not store the pointer long-term.
pub fn getBool(db: *storage.Database, key: [*:0]const u8) ?bool {
    if (db.getSetting(key)) |val| {
        const s = std.mem.span(val);
        if (std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "1")) return true;
        if (std.mem.eql(u8, s, "false") or std.mem.eql(u8, s, "0")) return false;
    }
    return null;
}
