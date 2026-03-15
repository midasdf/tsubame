const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;

pub const Database = struct {
    db: *c.sqlite3,

    const schema =
        \\CREATE TABLE IF NOT EXISTS history (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    url TEXT NOT NULL,
        \\    title TEXT,
        \\    visited_at INTEGER NOT NULL
        \\);
        \\CREATE INDEX IF NOT EXISTS idx_history_visited ON history(visited_at DESC);
        \\CREATE INDEX IF NOT EXISTS idx_history_url ON history(url);
        \\CREATE TABLE IF NOT EXISTS bookmarks (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    url TEXT NOT NULL UNIQUE,
        \\    title TEXT,
        \\    created_at INTEGER NOT NULL
        \\);
        \\CREATE TABLE IF NOT EXISTS downloads (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    url TEXT NOT NULL,
        \\    filepath TEXT NOT NULL,
        \\    filesize INTEGER,
        \\    status TEXT NOT NULL DEFAULT 'in_progress',
        \\    started_at INTEGER NOT NULL,
        \\    finished_at INTEGER
        \\);
        \\CREATE TABLE IF NOT EXISTS sessions (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    tab_id INTEGER NOT NULL,
        \\    url TEXT NOT NULL,
        \\    title TEXT,
        \\    scroll_x REAL DEFAULT 0,
        \\    scroll_y REAL DEFAULT 0,
        \\    position INTEGER NOT NULL,
        \\    is_current INTEGER DEFAULT 0
        \\);
        \\CREATE TABLE IF NOT EXISTS settings (
        \\    key TEXT PRIMARY KEY,
        \\    value TEXT
        \\);
    ;

    const default_settings =
        \\INSERT OR IGNORE INTO settings (key, value) VALUES ('max_active_tabs', '3');
        \\INSERT OR IGNORE INTO settings (key, value) VALUES ('homepage', 'https://duckduckgo.com');
    ;

    pub fn open(path: [*:0]const u8) !Database {
        var db: ?*c.sqlite3 = null;
        const rc = c.sqlite3_open(path, &db);
        if (rc != c.SQLITE_OK) {
            if (db) |d| _ = c.sqlite3_close(d);
            return error.SqliteOpenFailed;
        }
        var self = Database{ .db = db.? };
        try self.exec(schema);
        try self.exec(default_settings);
        return self;
    }

    pub fn close(self: *Database) void {
        _ = c.sqlite3_close(self.db);
    }

    pub fn exec(self: *Database, sql: [*:0]const u8) !void {
        var err_msg: [*c]u8 = null;
        const rc = c.sqlite3_exec(self.db, sql, null, null, &err_msg);
        if (rc != c.SQLITE_OK) {
            if (err_msg) |msg| {
                std.log.err("SQLite error: {s}", .{msg});
                c.sqlite3_free(msg);
            }
            return error.SqliteExecFailed;
        }
    }

    pub fn prepare(self: *Database, sql: [*:0]const u8) !*c.sqlite3_stmt {
        var stmt: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (rc != c.SQLITE_OK) {
            std.log.err("SQLite prepare error: {s}", .{c.sqlite3_errmsg(self.db)});
            return error.SqlitePrepareFailed;
        }
        return stmt.?;
    }

    pub fn getSetting(self: *Database, key: [*:0]const u8) ?[*:0]const u8 {
        const stmt = self.prepare("SELECT value FROM settings WHERE key = ?") catch return null;
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_text(stmt, 1, key, -1, null);
        if (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            return c.sqlite3_column_text(stmt, 0);
        }
        return null;
    }
};

var data_dir_buf: [512]u8 = undefined;
var data_dir_len: usize = 0;

pub fn ensureDataDir() ![]const u8 {
    const home = std.posix.getenv("HOME") orelse return error.NoHome;
    const data_home = std.posix.getenv("XDG_DATA_HOME");

    const dir = if (data_home) |dh|
        std.fmt.bufPrint(&data_dir_buf, "{s}/tsubame", .{dh}) catch return error.PathTooLong
    else
        std.fmt.bufPrint(&data_dir_buf, "{s}/.local/share/tsubame", .{home}) catch return error.PathTooLong;

    data_dir_len = dir.len;

    std.fs.cwd().makePath(dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return error.MkdirFailed,
    };

    return data_dir_buf[0..data_dir_len];
}

pub fn getDataDir() []const u8 {
    return data_dir_buf[0..data_dir_len];
}
