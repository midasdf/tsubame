const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;
const storage = @import("storage.zig");
const browser = @import("browser.zig");

const APP_NAME = "Tsubame";
const DEFAULT_URL = "https://duckduckgo.com";

pub fn main() !void {
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
    _ = &db;

    _ = c.gtk_init(null, null);
    browser.setupCookies();

    // Create window
    const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL);
    c.gtk_window_set_title(ch.GTK_WINDOW(window), APP_NAME);
    c.gtk_window_set_default_size(ch.GTK_WINDOW(window), 1024, 768);
    ch.connectSignalNoData(window, "destroy", &c.gtk_main_quit);

    // Create WebView via browser module
    const webview = browser.createWebView();
    c.gtk_container_add(ch.GTK_CONTAINER(window), webview);
    browser.loadUri(webview, DEFAULT_URL);

    // Show and run
    c.gtk_widget_show_all(window);
    c.gtk_main();
}
