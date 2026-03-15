const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");
const browser = @import("browser.zig");
const ui_mod = @import("ui.zig");
const tabs_mod = @import("tabs.zig");
const history = @import("history.zig");
const bookmarks = @import("bookmarks.zig");
const search = @import("search.zig");
const downloads = @import("downloads.zig");

const DEFAULT_URL = "https://duckduckgo.com";
var g_allocator: std.mem.Allocator = undefined;

// Global state (needed for GTK C callbacks)
var g_pool: *tabs_mod.TabPool = undefined;
var g_ui: ui_mod.UiState = undefined;
var g_db: *storage.Database = undefined;

fn onLoadChanged(_: *c.WebKitWebView, event: c_uint, _: ?*anyopaque) callconv(.c) void {
    if (event == c.WEBKIT_LOAD_COMMITTED) {
        if (g_pool.currentTab()) |tab| {
            if (tab.webview) |wv| {
                if (browser.getUri(wv)) |uri| {
                    tab.updateUrl(g_pool.allocator, uri);
                    c.gtk_entry_set_text(ch.GTK_ENTRY(g_ui.url_entry), uri);
                    // Update bookmark indicator
                    const is_bm = bookmarks.isBookmarked(g_db, uri);
                    c.gtk_button_set_label(ch.GTK_BUTTON(g_ui.bookmark_btn), if (is_bm) "\xE2\x98\x85" else "\xE2\x98\x86");
                }
            }
        }
    }
    if (event == c.WEBKIT_LOAD_FINISHED) {
        if (g_pool.currentTab()) |tab| {
            if (tab.url) |url| {
                const title_ptr: ?[*:0]const u8 = if (tab.title) |t| t.ptr else null;
                history.recordVisit(g_db, url.ptr, title_ptr);
            }
        }
    }
}

fn onTitleChanged(_: *c.WebKitWebView, _: ?*c.GParamSpec, _: ?*anyopaque) callconv(.c) void {
    if (g_pool.currentTab()) |tab| {
        if (tab.webview) |wv| {
            if (browser.getTitle(wv)) |title| {
                tab.updateTitle(g_pool.allocator, title);
                c.gtk_window_set_title(ch.GTK_WINDOW(g_ui.window), title);
                if (tab.tab_button) |btn| {
                    c.gtk_button_set_label(ch.GTK_BUTTON(btn), title);
                }
            }
        }
    }
}

fn onUrlEntryActivate(_: *c.GtkEntry, _: ?*anyopaque) callconv(.c) void {
    const text = c.gtk_entry_get_text(ch.GTK_ENTRY(g_ui.url_entry));
    if (text == null) return;

    if (g_pool.currentWebView()) |wv| {
        const span = std.mem.span(text.?);
        if (std.mem.startsWith(u8, span, "http://") or
            std.mem.startsWith(u8, span, "https://") or
            std.mem.startsWith(u8, span, "tsubame://"))
        {
            browser.loadUri(wv, text.?);
        } else {
            var buf: [2048]u8 = undefined;
            const uri = std.fmt.bufPrintZ(&buf, "https://{s}", .{span}) catch return;
            browser.loadUri(wv, uri.ptr);
        }
    }
}

fn onBackClicked(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    if (g_pool.currentWebView()) |wv| browser.goBack(wv);
}

fn onForwardClicked(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    if (g_pool.currentWebView()) |wv| browser.goForward(wv);
}

fn onReloadClicked(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    if (g_pool.currentWebView()) |wv| browser.reload(wv);
}

fn onNewTabClicked(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    _ = g_pool.newTab(DEFAULT_URL) catch {};
}

fn onBookmarkClicked(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    toggleCurrentBookmark();
}

fn toggleCurrentBookmark() void {
    if (g_pool.currentTab()) |tab| {
        if (tab.url) |url| {
            const title_ptr: ?[*:0]const u8 = if (tab.title) |t| t.ptr else null;
            const added = bookmarks.toggleBookmark(g_db, url.ptr, title_ptr);
            c.gtk_button_set_label(ch.GTK_BUTTON(g_ui.bookmark_btn), if (added) "\xE2\x98\x85" else "\xE2\x98\x86");
        }
    }
}

fn onFindEntryActivate(_: *c.GtkEntry, _: ?*anyopaque) callconv(.c) void {
    const text = c.gtk_entry_get_text(ch.GTK_ENTRY(g_ui.find_entry));
    if (g_pool.currentWebView()) |wv| {
        search.findInPage(wv, text.?, true);
    }
}

fn onFindNext(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    if (g_pool.currentWebView()) |wv| search.findNext(wv);
}

fn onFindPrev(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    if (g_pool.currentWebView()) |wv| search.findPrev(wv);
}

fn onFindClose(_: *c.GtkButton, _: ?*anyopaque) callconv(.c) void {
    c.gtk_widget_hide(g_ui.find_bar);
    if (g_pool.currentWebView()) |wv| search.clearFind(wv);
}

fn onCustomUri(request: [*c]c.WebKitURISchemeRequest, _: ?*anyopaque) callconv(.c) void {
    const uri = c.webkit_uri_scheme_request_get_uri(request);
    if (uri == null) return;
    const span = std.mem.span(uri.?);

    var html: ?[]const u8 = null;

    if (std.mem.eql(u8, span, "tsubame://history")) {
        html = history.generateHistoryPage(g_db, g_allocator);
    } else if (std.mem.eql(u8, span, "tsubame://bookmarks")) {
        html = bookmarks.generateBookmarksPage(g_db, g_allocator);
    }

    if (html) |h| {
        defer g_allocator.free(h);
        const bytes = c.g_bytes_new(h.ptr, h.len);
        const stream = c.g_memory_input_stream_new_from_bytes(bytes);
        c.webkit_uri_scheme_request_finish(request, stream, @intCast(h.len), "text/html");
        c.g_object_unref(stream);
        c.g_bytes_unref(bytes);
    }
}

fn connectWebViewSignals(webview: *c.GtkWidget) void {
    ch.connectSignalNoData(webview, "load-changed", &onLoadChanged);
    ch.connectSignalNoData(webview, "notify::title", &onTitleChanged);
}

fn onTabSwitch(pool: *tabs_mod.TabPool, idx: usize) void {
    const tab = &pool.tabs.items[idx];
    if (tab.url) |url| {
        c.gtk_entry_set_text(ch.GTK_ENTRY(g_ui.url_entry), url.ptr);
    }
    if (tab.title) |title| {
        c.gtk_window_set_title(ch.GTK_WINDOW(g_ui.window), title.ptr);
    } else {
        c.gtk_window_set_title(ch.GTK_WINDOW(g_ui.window), "Tsubame");
    }
}

fn onKeyPress(_: *c.GtkWidget, event_ptr: ?*anyopaque, _: ?*anyopaque) callconv(.c) c_int {
    // GdkEventKey is opaque to @cImport due to bitfields, so we define the layout manually
    const EventKey = extern struct {
        type: c_int,
        window: ?*anyopaque,
        send_event: i8,
        time: u32,
        state: c_uint,
        keyval: c_uint,
    };
    const event: *const EventKey = @ptrCast(@alignCast(event_ptr orelse return 0));
    const ctrl = event.state & c.GDK_CONTROL_MASK != 0;
    const alt = event.state & c.GDK_MOD1_MASK != 0;
    const shift = event.state & c.GDK_SHIFT_MASK != 0;

    if (ctrl) {
        switch (event.keyval) {
            c.GDK_KEY_t, c.GDK_KEY_T => {
                _ = g_pool.newTab(DEFAULT_URL) catch {};
                return 1;
            },
            c.GDK_KEY_w, c.GDK_KEY_W => {
                if (g_pool.current_index) |idx| g_pool.closeTab(idx);
                return 1;
            },
            c.GDK_KEY_Tab => {
                if (g_pool.current_index) |idx| {
                    if (shift) {
                        const prev = if (idx > 0) idx - 1 else g_pool.tabs.items.len - 1;
                        g_pool.switchTo(prev);
                    } else {
                        const next = if (idx + 1 < g_pool.tabs.items.len) idx + 1 else 0;
                        g_pool.switchTo(next);
                    }
                }
                return 1;
            },
            c.GDK_KEY_ISO_Left_Tab => {
                if (g_pool.current_index) |idx| {
                    const prev = if (idx > 0) idx - 1 else g_pool.tabs.items.len - 1;
                    g_pool.switchTo(prev);
                }
                return 1;
            },
            c.GDK_KEY_l, c.GDK_KEY_L => {
                c.gtk_widget_grab_focus(g_ui.url_entry);
                c.gtk_editable_select_region(ch.GTK_EDITABLE(g_ui.url_entry), 0, -1);
                return 1;
            },
            c.GDK_KEY_f, c.GDK_KEY_F => {
                c.gtk_widget_show_all(g_ui.find_bar);
                c.gtk_widget_grab_focus(g_ui.find_entry);
                return 1;
            },
            c.GDK_KEY_r, c.GDK_KEY_R => {
                if (g_pool.currentWebView()) |wv| browser.reload(wv);
                return 1;
            },
            c.GDK_KEY_q, c.GDK_KEY_Q => {
                g_pool.saveSession(g_db);
                c.gtk_main_quit();
                return 1;
            },
            c.GDK_KEY_d, c.GDK_KEY_D => {
                toggleCurrentBookmark();
                return 1;
            },
            c.GDK_KEY_h, c.GDK_KEY_H => {
                if (g_pool.currentWebView()) |wv| browser.loadUri(wv, "tsubame://history");
                return 1;
            },
            c.GDK_KEY_1...c.GDK_KEY_9 => {
                const n = event.keyval - c.GDK_KEY_1;
                if (n < g_pool.tabs.items.len) g_pool.switchTo(n);
                return 1;
            },
            else => {},
        }
    }

    if (alt) {
        switch (event.keyval) {
            c.GDK_KEY_Left => {
                if (g_pool.currentWebView()) |wv| browser.goBack(wv);
                return 1;
            },
            c.GDK_KEY_Right => {
                if (g_pool.currentWebView()) |wv| browser.goForward(wv);
                return 1;
            },
            else => {},
        }
    }

    switch (event.keyval) {
        c.GDK_KEY_F5 => {
            if (g_pool.currentWebView()) |wv| browser.reload(wv);
            return 1;
        },
        c.GDK_KEY_Escape => {
            if (g_pool.currentWebView()) |wv| {
                browser.stopLoading(wv);
                search.clearFind(wv);
            }
            c.gtk_widget_hide(g_ui.find_bar);
            return 1;
        },
        else => {},
    }

    return 0;
}

fn onDeleteEvent(_: *c.GtkWidget, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) c_int {
    g_pool.saveSession(g_db);
    return 0; // allow window to close
}

fn onDestroy(_: *c.GtkWidget, _: ?*anyopaque) callconv(.c) void {
    c.gtk_main_quit();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Init storage
    const data_dir = storage.ensureDataDir() catch {
        std.debug.print("Error: could not create data directory\n", .{});
        return;
    };

    var path_buf: [512]u8 = undefined;
    const db_path = std.fmt.bufPrint(&path_buf, "{s}/tsubame.db", .{data_dir}) catch return;
    path_buf[db_path.len] = 0;

    var db = storage.Database.open(path_buf[0..db_path.len :0]) catch {
        std.debug.print("Error: could not open database\n", .{});
        return;
    };
    defer db.close();
    g_db = &db;

    g_allocator = allocator;

    _ = c.gtk_init(null, null);
    browser.setupCookies();

    // Register custom URI scheme
    const ctx = c.webkit_web_context_get_default();
    c.webkit_web_context_register_uri_scheme(ctx, "tsubame", &onCustomUri, null, null);

    // Build UI
    g_ui = ui_mod.buildUi();
    ch.connectSignalNoData(g_ui.window, "delete-event", &onDeleteEvent);
    ch.connectSignalNoData(g_ui.window, "destroy", &onDestroy);

    // Read max_active_tabs
    var max_active: u32 = 3;
    if (db.getSetting("max_active_tabs")) |val| {
        const span = std.mem.span(val);
        max_active = std.fmt.parseInt(u32, span, 10) catch 3;
    }

    // Init tab pool
    var pool = tabs_mod.TabPool.init(allocator, g_ui.web_stack, g_ui.tab_bar, max_active);
    defer pool.deinit();
    g_pool = &pool;

    pool.on_new_webview = &connectWebViewSignals;
    pool.on_tab_switch_cb = &onTabSwitch;

    // Setup downloads
    downloads.setup(&db, g_ui.download_bar, g_ui.download_label);

    // Try to restore previous session
    const restored = pool.restoreSession(&db) catch false;
    if (!restored) {
        _ = pool.newTab(DEFAULT_URL) catch {
            std.debug.print("Error: could not create initial tab\n", .{});
            return;
        };
    }

    // Connect toolbar signals
    ch.connectSignalNoData(g_ui.back_btn, "clicked", &onBackClicked);
    ch.connectSignalNoData(g_ui.forward_btn, "clicked", &onForwardClicked);
    ch.connectSignalNoData(g_ui.reload_btn, "clicked", &onReloadClicked);
    ch.connectSignalNoData(g_ui.new_tab_btn, "clicked", &onNewTabClicked);
    ch.connectSignalNoData(g_ui.url_entry, "activate", &onUrlEntryActivate);
    ch.connectSignalNoData(g_ui.window, "key-press-event", &onKeyPress);
    ch.connectSignalNoData(g_ui.bookmark_btn, "clicked", &onBookmarkClicked);
    ch.connectSignalNoData(g_ui.find_entry, "activate", &onFindEntryActivate);
    ch.connectSignalNoData(g_ui.find_next_btn, "clicked", &onFindNext);
    ch.connectSignalNoData(g_ui.find_prev_btn, "clicked", &onFindPrev);
    ch.connectSignalNoData(g_ui.find_close_btn, "clicked", &onFindClose);

    // Auto-save session every 30 seconds
    _ = c.g_timeout_add(30000, &autoSaveSession, null);

    c.gtk_widget_show_all(g_ui.window);
    c.gtk_main();
}

fn autoSaveSession(_: ?*anyopaque) callconv(.c) c_int {
    g_pool.saveSession(g_db);
    return 1; // keep repeating
}
