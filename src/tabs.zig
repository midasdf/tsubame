const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const browser = @import("browser.zig");

const private_mod = @import("private.zig");

pub const TabState = struct {
    id: u32,
    url: ?[:0]u8,
    title: ?[:0]u8,
    scroll_x: f64,
    scroll_y: f64,
    is_active: bool,
    is_private: bool,
    webview: ?*c.GtkWidget,
    last_accessed: i64,
    tab_box: ?*c.GtkWidget,
    tab_button: ?*c.GtkWidget,

    pub fn deinit(self: *TabState, allocator: std.mem.Allocator) void {
        if (self.url) |u| allocator.free(u);
        if (self.title) |t| allocator.free(t);
    }

    pub fn updateUrl(self: *TabState, allocator: std.mem.Allocator, new_url: [*:0]const u8) void {
        const span = std.mem.span(new_url);
        const new = allocator.dupeZ(u8, span) catch return;
        if (self.url) |old| allocator.free(old);
        self.url = new;
    }

    pub fn updateTitle(self: *TabState, allocator: std.mem.Allocator, new_title: [*:0]const u8) void {
        const span = std.mem.span(new_title);
        const new = allocator.dupeZ(u8, span) catch return;
        if (self.title) |old| allocator.free(old);
        self.title = new;
    }
};

pub const TabPool = struct {
    tabs: std.ArrayListUnmanaged(TabState),
    allocator: std.mem.Allocator,
    next_id: u32,
    current_index: ?usize,
    max_active: u32,
    web_stack: *c.GtkWidget,
    tab_bar: *c.GtkWidget,
    on_new_webview: ?*const fn (*c.GtkWidget) void,
    on_tab_switch_cb: ?*const fn (*TabPool, usize) void,

    pub fn init(
        allocator: std.mem.Allocator,
        web_stack: *c.GtkWidget,
        tab_bar: *c.GtkWidget,
        max_active: u32,
    ) TabPool {
        return TabPool{
            .tabs = .empty,
            .allocator = allocator,
            .next_id = 0,
            .current_index = null,
            .max_active = max_active,
            .web_stack = web_stack,
            .tab_bar = tab_bar,
            .on_new_webview = null,
            .on_tab_switch_cb = null,
        };
    }

    pub fn deinit(self: *TabPool) void {
        for (self.tabs.items) |*tab| {
            tab.deinit(self.allocator);
        }
        self.tabs.deinit(self.allocator);
    }

    fn activeCount(self: *TabPool) u32 {
        var count: u32 = 0;
        for (self.tabs.items) |tab| {
            if (tab.is_active) count += 1;
        }
        return count;
    }

    fn findLruActive(self: *TabPool) ?usize {
        var oldest_time: i64 = std.math.maxInt(i64);
        var oldest_idx: ?usize = null;
        for (self.tabs.items, 0..) |tab, i| {
            if (tab.is_active and self.current_index != i) {
                if (tab.last_accessed < oldest_time) {
                    oldest_time = tab.last_accessed;
                    oldest_idx = i;
                }
            }
        }
        return oldest_idx;
    }

    fn suspendTab(self: *TabPool, idx: usize) void {
        var tab = &self.tabs.items[idx];
        if (!tab.is_active or tab.webview == null) return;

        c.gtk_container_remove(ch.GTK_CONTAINER(self.web_stack), tab.webview.?);
        tab.webview = null;
        tab.is_active = false;

        if (tab.tab_box) |box| {
            c.gtk_widget_set_sensitive(box, 0);
        }
    }

    fn restoreTab(self: *TabPool, idx: usize) void {
        var tab = &self.tabs.items[idx];
        if (tab.is_active) return;

        if (self.activeCount() >= self.max_active) {
            if (self.findLruActive()) |lru_idx| {
                self.suspendTab(lru_idx);
            }
        }

        const webview = browser.createWebView();
        tab.webview = webview;
        tab.is_active = true;

        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrintZ(&name_buf, "tab-{d}", .{tab.id}) catch return;
        c.gtk_stack_add_named(ch.GTK_STACK(self.web_stack), webview, name.ptr);
        c.gtk_widget_show(webview);

        if (tab.url) |url| {
            browser.loadUri(webview, url.ptr);
        }

        if (tab.tab_box) |box| {
            c.gtk_widget_set_sensitive(box, 1);
        }

        if (self.on_new_webview) |cb| cb(webview);
    }

    pub fn newTab(self: *TabPool, url: [*:0]const u8) !usize {
        return self.newTabEx(url, false);
    }

    pub fn newPrivateTab(self: *TabPool, url: [*:0]const u8) !usize {
        return self.newTabEx(url, true);
    }

    fn newTabEx(self: *TabPool, url: [*:0]const u8, is_private: bool) !usize {
        if (self.activeCount() >= self.max_active) {
            if (self.findLruActive()) |lru_idx| {
                self.suspendTab(lru_idx);
            }
        }

        const id = self.next_id;
        self.next_id += 1;

        const webview = if (is_private) private_mod.createPrivateWebView() else browser.createWebView();

        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrintZ(&name_buf, "tab-{d}", .{id}) catch return error.FmtError;
        c.gtk_stack_add_named(ch.GTK_STACK(self.web_stack), webview, name.ptr);
        c.gtk_widget_show(webview);

        // Create tab widget: [label_button] [close_button] in a box
        var id_buf: [32]u8 = undefined;
        const id_str = std.fmt.bufPrintZ(&id_buf, "{d}", .{id}) catch return error.FmtError;

        // Container box for the tab
        const tab_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0);
        c.gtk_widget_set_name(tab_box, id_str.ptr);

        // Label button (clickable area to switch tab)
        var label_buf: [64]u8 = undefined;
        const label_text = if (is_private)
            std.fmt.bufPrintZ(&label_buf, "\xF0\x9F\x94\x92 Tab {d}", .{id + 1}) catch return error.FmtError
        else
            std.fmt.bufPrintZ(&label_buf, "Tab {d}", .{id + 1}) catch return error.FmtError;

        const tab_button = c.gtk_button_new_with_label(label_text.ptr);
        c.gtk_box_pack_start(ch.GTK_BOX(tab_box), tab_button, 1, 1, 0);

        // Close button ×
        const close_btn = c.gtk_button_new_with_label("x");
        c.gtk_box_pack_start(ch.GTK_BOX(tab_box), close_btn, 0, 0, 0);

        c.gtk_box_pack_start(ch.GTK_BOX(self.tab_bar), tab_box, 0, 0, 0);
        c.gtk_widget_show_all(tab_box);

        // Store tab ID on each button via GObject data
        const id_as_ptr = @as(?*anyopaque, @ptrFromInt(@as(usize, id) + 1)); // +1 to avoid null
        _ = c.g_object_set_data(@ptrCast(@alignCast(tab_button)), "tab-id", id_as_ptr);
        _ = c.g_object_set_data(@ptrCast(@alignCast(close_btn)), "tab-id", id_as_ptr);

        ch.connectSignal(tab_button, "clicked", &onTabButtonClicked, self);
        ch.connectSignal(close_btn, "clicked", &onTabCloseClicked, self);

        const now = std.time.timestamp();

        const tab = TabState{
            .id = id,
            .url = self.allocator.dupeZ(u8, std.mem.span(url)) catch null,
            .title = null,
            .scroll_x = 0,
            .scroll_y = 0,
            .is_active = true,
            .is_private = is_private,
            .webview = webview,
            .last_accessed = now,
            .tab_box = tab_box,
            .tab_button = tab_button,
        };

        try self.tabs.append(self.allocator, tab);
        const idx = self.tabs.items.len - 1;

        browser.loadUri(webview, url);

        if (self.on_new_webview) |cb| cb(webview);

        self.switchTo(idx);

        return idx;
    }

    pub fn switchTo(self: *TabPool, idx: usize) void {
        if (idx >= self.tabs.items.len) return;

        var tab = &self.tabs.items[idx];
        tab.last_accessed = std.time.timestamp();

        if (!tab.is_active) {
            self.restoreTab(idx);
        }

        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrintZ(&name_buf, "tab-{d}", .{tab.id}) catch return;
        c.gtk_stack_set_visible_child_name(ch.GTK_STACK(self.web_stack), name.ptr);

        self.current_index = idx;

        if (self.on_tab_switch_cb) |cb| cb(self, idx);
    }

    pub fn closeTab(self: *TabPool, idx: usize) void {
        if (idx >= self.tabs.items.len) return;
        if (self.tabs.items.len <= 1) return;

        var tab = &self.tabs.items[idx];

        if (tab.is_active and tab.webview != null) {
            c.gtk_container_remove(ch.GTK_CONTAINER(self.web_stack), tab.webview.?);
        }

        if (tab.tab_box) |box| {
            c.gtk_container_remove(ch.GTK_CONTAINER(self.tab_bar), box);
        }

        tab.deinit(self.allocator);
        _ = self.tabs.orderedRemove(idx);

        if (self.current_index) |cur| {
            if (cur == idx) {
                const new_idx = if (idx > 0) idx - 1 else 0;
                self.switchTo(new_idx);
            } else if (cur > idx) {
                self.current_index = cur - 1;
            }
        }
    }

    pub fn currentTab(self: *TabPool) ?*TabState {
        if (self.current_index) |idx| {
            if (idx < self.tabs.items.len) {
                return &self.tabs.items[idx];
            }
        }
        return null;
    }

    pub fn currentWebView(self: *TabPool) ?*c.GtkWidget {
        if (self.currentTab()) |tab| {
            return tab.webview;
        }
        return null;
    }

    pub fn saveSession(self: *TabPool, db: *@import("storage.zig").Database) void {
        db.exec("DELETE FROM sessions") catch return;

        for (self.tabs.items, 0..) |tab, i| {
            const stmt = db.prepare(
                "INSERT INTO sessions (tab_id, url, title, scroll_x, scroll_y, position, is_current) VALUES (?, ?, ?, ?, ?, ?, ?)",
            ) catch continue;
            defer _ = c.sqlite3_finalize(stmt);

            _ = c.sqlite3_bind_int(stmt, 1, @intCast(tab.id));
            if (tab.url) |u| {
                _ = c.sqlite3_bind_text(stmt, 2, u.ptr, -1, null);
            } else {
                _ = c.sqlite3_bind_text(stmt, 2, "about:blank", -1, null);
            }
            if (tab.title) |t| {
                _ = c.sqlite3_bind_text(stmt, 3, t.ptr, -1, null);
            } else {
                _ = c.sqlite3_bind_null(stmt, 3);
            }
            _ = c.sqlite3_bind_double(stmt, 4, tab.scroll_x);
            _ = c.sqlite3_bind_double(stmt, 5, tab.scroll_y);
            _ = c.sqlite3_bind_int(stmt, 6, @intCast(i));
            _ = c.sqlite3_bind_int(stmt, 7, if (self.current_index == i) @as(c_int, 1) else @as(c_int, 0));
            _ = c.sqlite3_step(stmt);
        }
    }

    pub fn restoreSession(self: *TabPool, db: *@import("storage.zig").Database) !bool {
        const stmt = db.prepare(
            "SELECT url, is_current FROM sessions ORDER BY position ASC",
        ) catch return false;
        defer _ = c.sqlite3_finalize(stmt);

        var count: usize = 0;
        var current_idx: ?usize = null;

        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const url = c.sqlite3_column_text(stmt, 0) orelse continue;
            const is_current = c.sqlite3_column_int(stmt, 1);

            const idx = try self.newTab(url);
            if (is_current != 0) current_idx = idx;
            count += 1;
        }

        if (current_idx) |idx| self.switchTo(idx);

        return count > 0;
    }

    fn findTabById(pool: *TabPool, widget: anytype) ?usize {
        const raw = c.g_object_get_data(@ptrCast(@alignCast(widget)), "tab-id");
        if (raw == null) return null;
        const id_plus1 = @intFromPtr(raw.?);
        if (id_plus1 == 0) return null;
        const id: u32 = @intCast(id_plus1 - 1);

        for (pool.tabs.items, 0..) |tab, i| {
            if (tab.id == id) return i;
        }
        return null;
    }

    fn onTabButtonClicked(button: *c.GtkButton, user_data: ?*anyopaque) callconv(.c) void {
        const pool: *TabPool = @ptrCast(@alignCast(user_data orelse return));
        if (findTabById(pool, ch.GTK_WIDGET(button))) |i| {
            pool.switchTo(i);
        }
    }

    fn onTabCloseClicked(button: *c.GtkButton, user_data: ?*anyopaque) callconv(.c) void {
        const pool: *TabPool = @ptrCast(@alignCast(user_data orelse return));
        if (findTabById(pool, ch.GTK_WIDGET(button))) |i| {
            pool.closeTab(i);
        }
    }
};
