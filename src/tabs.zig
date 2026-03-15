const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const browser = @import("browser.zig");

pub const TabState = struct {
    id: u32,
    url: ?[:0]u8,
    title: ?[:0]u8,
    scroll_x: f64,
    scroll_y: f64,
    is_active: bool,
    webview: ?*c.GtkWidget,
    last_accessed: i64,
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

        if (tab.tab_button) |btn| {
            c.gtk_widget_set_sensitive(btn, 0);
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

        if (tab.tab_button) |btn| {
            c.gtk_widget_set_sensitive(btn, 1);
        }

        if (self.on_new_webview) |cb| cb(webview);
    }

    pub fn newTab(self: *TabPool, url: [*:0]const u8) !usize {
        if (self.activeCount() >= self.max_active) {
            if (self.findLruActive()) |lru_idx| {
                self.suspendTab(lru_idx);
            }
        }

        const id = self.next_id;
        self.next_id += 1;

        const webview = browser.createWebView();

        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrintZ(&name_buf, "tab-{d}", .{id}) catch return error.FmtError;
        c.gtk_stack_add_named(ch.GTK_STACK(self.web_stack), webview, name.ptr);
        c.gtk_widget_show(webview);

        // Create tab button with tab id as widget name for lookup
        var id_buf: [32]u8 = undefined;
        const id_str = std.fmt.bufPrintZ(&id_buf, "{d}", .{id}) catch return error.FmtError;

        var label_buf: [64]u8 = undefined;
        const label = std.fmt.bufPrintZ(&label_buf, "Tab {d}", .{id + 1}) catch return error.FmtError;
        const tab_button = c.gtk_button_new_with_label(label.ptr);
        c.gtk_widget_set_name(tab_button, id_str.ptr);
        c.gtk_box_pack_start(ch.GTK_BOX(self.tab_bar), tab_button, 0, 0, 0);
        c.gtk_widget_show(tab_button);

        ch.connectSignal(tab_button, "clicked", &onTabButtonClicked, self);

        const now = std.time.timestamp();

        const tab = TabState{
            .id = id,
            .url = self.allocator.dupeZ(u8, std.mem.span(url)) catch null,
            .title = null,
            .scroll_x = 0,
            .scroll_y = 0,
            .is_active = true,
            .webview = webview,
            .last_accessed = now,
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

        if (tab.tab_button) |btn| {
            c.gtk_container_remove(ch.GTK_CONTAINER(self.tab_bar), btn);
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

    fn onTabButtonClicked(button: *c.GtkButton, user_data: ?*anyopaque) callconv(.c) void {
        const pool: *TabPool = @ptrCast(@alignCast(user_data orelse return));
        const name = c.gtk_widget_get_name(ch.GTK_WIDGET(button));
        if (name == null) return;
        const id = std.fmt.parseInt(u32, std.mem.span(name.?), 10) catch return;

        for (pool.tabs.items, 0..) |tab, i| {
            if (tab.id == id) {
                pool.switchTo(i);
                break;
            }
        }
    }
};
