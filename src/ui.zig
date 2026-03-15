const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;

pub const UiState = struct {
    window: *c.GtkWidget,
    vbox: *c.GtkWidget,
    url_entry: *c.GtkWidget,
    tab_bar: *c.GtkWidget,
    web_stack: *c.GtkWidget,
    split_paned: ?*c.GtkWidget,
    split_webview: ?*c.GtkWidget,
    is_split: bool,
    find_bar: *c.GtkWidget,
    find_entry: *c.GtkWidget,
    find_prev_btn: *c.GtkWidget,
    find_next_btn: *c.GtkWidget,
    find_close_btn: *c.GtkWidget,
    download_bar: *c.GtkWidget,
    download_label: *c.GtkWidget,
    bookmark_btn: *c.GtkWidget,
    back_btn: *c.GtkWidget,
    forward_btn: *c.GtkWidget,
    reload_btn: *c.GtkWidget,
    new_tab_btn: *c.GtkWidget,
};

const dark_css =
    \\/* Tsubame dark theme */
    \\
    \\/* Force dark background on all chrome */
    \\window, .background {
    \\    background-color: #1e1e2e;
    \\    color: #cdd6f4;
    \\}
    \\
    \\/* Toolbar area */
    \\#toolbar {
    \\    background-color: #181825;
    \\    padding: 2px 4px;
    \\    border-bottom: 1px solid #313244;
    \\}
    \\
    \\#toolbar button {
    \\    background: transparent;
    \\    border: none;
    \\    color: #cdd6f4;
    \\    padding: 4px 8px;
    \\    min-width: 0;
    \\    min-height: 0;
    \\}
    \\
    \\#toolbar button:hover {
    \\    background-color: #313244;
    \\    border-radius: 4px;
    \\}
    \\
    \\/* URL entry */
    \\#url-entry {
    \\    background-color: #313244;
    \\    color: #cdd6f4;
    \\    border: 1px solid #45475a;
    \\    border-radius: 6px;
    \\    padding: 4px 8px;
    \\    caret-color: #89b4fa;
    \\}
    \\
    \\#url-entry:focus {
    \\    border-color: #89b4fa;
    \\}
    \\
    \\/* Tab bar */
    \\#tab-bar {
    \\    background-color: #11111b;
    \\    padding: 2px 4px;
    \\    border-bottom: 1px solid #313244;
    \\}
    \\
    \\#tab-bar > box {
    \\    background-color: #1e1e2e;
    \\    border: 1px solid #313244;
    \\    border-radius: 6px 6px 0 0;
    \\    margin-right: 2px;
    \\}
    \\
    \\#tab-bar > box:disabled {
    \\    background-color: #11111b;
    \\    border-color: #181825;
    \\}
    \\
    \\#tab-bar button {
    \\    background: transparent;
    \\    border: none;
    \\    color: #a6adc8;
    \\    padding: 4px 8px;
    \\    min-width: 0;
    \\    min-height: 0;
    \\}
    \\
    \\#tab-bar button:hover {
    \\    background-color: #313244;
    \\    color: #cdd6f4;
    \\}
    \\
    \\.close-btn {
    \\    padding: 4px 6px;
    \\    color: #585b70;
    \\}
    \\
    \\.close-btn:hover {
    \\    color: #f38ba8;
    \\}
    \\
    \\/* New tab button */
    \\#new-tab-btn {
    \\    background: transparent;
    \\    color: #585b70;
    \\    border: 1px dashed #45475a;
    \\    border-radius: 6px 6px 0 0;
    \\    padding: 3px 8px;
    \\}
    \\
    \\#new-tab-btn:hover {
    \\    color: #89b4fa;
    \\    border-color: #89b4fa;
    \\}
    \\
    \\/* Bookmark button */
    \\#bookmark-btn {
    \\    color: #f9e2af;
    \\}
    \\
    \\/* Find bar */
    \\#find-bar {
    \\    background-color: #181825;
    \\    padding: 4px 8px;
    \\    border-top: 1px solid #313244;
    \\}
    \\
    \\#find-bar entry {
    \\    background-color: #313244;
    \\    color: #cdd6f4;
    \\    border: 1px solid #45475a;
    \\    border-radius: 4px;
    \\    padding: 2px 6px;
    \\}
    \\
    \\#find-bar button {
    \\    background: transparent;
    \\    color: #cdd6f4;
    \\    border: none;
    \\    padding: 2px 6px;
    \\    min-width: 0;
    \\    min-height: 0;
    \\}
    \\
    \\#find-bar button:hover {
    \\    background-color: #313244;
    \\    border-radius: 4px;
    \\}
    \\
    \\#find-bar label {
    \\    color: #a6adc8;
    \\}
    \\
    \\/* Download bar */
    \\#download-bar {
    \\    background-color: #1e1e2e;
    \\    padding: 4px 8px;
    \\    border-top: 1px solid #313244;
    \\}
    \\
    \\#download-bar label {
    \\    color: #a6e3a1;
    \\}
;

fn applyDarkTheme() void {
    // Enable GTK dark theme preference
    const gtk_settings = c.gtk_settings_get_default();
    _ = c.g_object_set(
        @as(*c.GObject, @ptrCast(@alignCast(gtk_settings))),
        "gtk-application-prefer-dark-theme",
        @as(c_int, 1),
        @as(?*anyopaque, null),
    );

    // Load custom CSS
    const provider = c.gtk_css_provider_new();
    _ = c.gtk_css_provider_load_from_data(
        provider,
        dark_css,
        -1,
        null,
    );
    c.gtk_style_context_add_provider_for_screen(
        c.gdk_screen_get_default(),
        @ptrCast(@alignCast(provider)),
        c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}

pub fn buildUi() UiState {
    applyDarkTheme();

    // Window
    const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL);
    c.gtk_window_set_title(ch.GTK_WINDOW(window), "Tsubame");
    c.gtk_window_set_default_size(ch.GTK_WINDOW(window), 1024, 768);

    // Main vertical box
    const vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0);
    c.gtk_container_add(ch.GTK_CONTAINER(window), vbox);

    // --- Toolbar ---
    const toolbar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 2);
    c.gtk_widget_set_name(toolbar, "toolbar");
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), toolbar, 0, 0, 0);

    const back_btn = c.gtk_button_new_with_label("\xE2\x97\x80"); // ◀
    const forward_btn = c.gtk_button_new_with_label("\xE2\x96\xB6"); // ▶
    const reload_btn = c.gtk_button_new_with_label("\xE2\x9F\xB3"); // ⟳

    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), back_btn, 0, 0, 0);
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), forward_btn, 0, 0, 0);
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), reload_btn, 0, 0, 0);

    const url_entry = c.gtk_entry_new();
    c.gtk_widget_set_name(url_entry, "url-entry");
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), url_entry, 1, 1, 4);

    const bookmark_btn = c.gtk_button_new_with_label("\xE2\x98\x86"); // ☆
    c.gtk_widget_set_name(bookmark_btn, "bookmark-btn");
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), bookmark_btn, 0, 0, 0);

    // --- Tab bar ---
    const tab_bar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 1);
    c.gtk_widget_set_name(tab_bar, "tab-bar");
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), tab_bar, 0, 0, 0);

    const new_tab_btn = c.gtk_button_new_with_label("+");
    c.gtk_widget_set_name(new_tab_btn, "new-tab-btn");
    c.gtk_box_pack_end(ch.GTK_BOX(tab_bar), new_tab_btn, 0, 0, 0);

    // --- Web content area (GtkStack) ---
    const web_stack = c.gtk_stack_new();
    c.gtk_stack_set_transition_type(ch.GTK_STACK(web_stack), c.GTK_STACK_TRANSITION_TYPE_NONE);
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), web_stack, 1, 1, 0);

    // --- Find bar (hidden by default) ---
    const find_bar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 2);
    c.gtk_widget_set_name(find_bar, "find-bar");
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), find_bar, 0, 0, 0);
    c.gtk_widget_set_no_show_all(find_bar, 1);

    const find_label = c.gtk_label_new("Find:");
    const find_entry = c.gtk_entry_new();
    const find_prev = c.gtk_button_new_with_label("\xE2\x96\xB2"); // ▲
    const find_next = c.gtk_button_new_with_label("\xE2\x96\xBC"); // ▼
    const find_close = c.gtk_button_new_with_label("\xE2\x9C\x95"); // ✕

    c.gtk_box_pack_start(ch.GTK_BOX(find_bar), find_label, 0, 0, 4);
    c.gtk_box_pack_start(ch.GTK_BOX(find_bar), find_entry, 1, 1, 0);
    c.gtk_box_pack_start(ch.GTK_BOX(find_bar), find_prev, 0, 0, 0);
    c.gtk_box_pack_start(ch.GTK_BOX(find_bar), find_next, 0, 0, 0);
    c.gtk_box_pack_start(ch.GTK_BOX(find_bar), find_close, 0, 0, 0);

    // --- Download bar (hidden by default) ---
    const download_bar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 4);
    c.gtk_widget_set_name(download_bar, "download-bar");
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), download_bar, 0, 0, 0);
    c.gtk_widget_set_no_show_all(download_bar, 1);

    const download_label = c.gtk_label_new("");
    c.gtk_box_pack_start(ch.GTK_BOX(download_bar), download_label, 1, 1, 4);

    return UiState{
        .window = window,
        .vbox = vbox,
        .url_entry = url_entry,
        .tab_bar = tab_bar,
        .web_stack = web_stack,
        .split_paned = null,
        .split_webview = null,
        .is_split = false,
        .find_bar = find_bar,
        .find_entry = find_entry,
        .find_prev_btn = find_prev,
        .find_next_btn = find_next,
        .find_close_btn = find_close,
        .download_bar = download_bar,
        .download_label = download_label,
        .bookmark_btn = bookmark_btn,
        .back_btn = back_btn,
        .forward_btn = forward_btn,
        .reload_btn = reload_btn,
        .new_tab_btn = new_tab_btn,
    };
}
