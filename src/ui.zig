const std = @import("std");
const ch = @import("c_helpers.zig");
const c = ch.c;

pub const UiState = struct {
    window: *c.GtkWidget,
    url_entry: *c.GtkWidget,
    tab_bar: *c.GtkWidget,
    web_stack: *c.GtkWidget,
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

pub fn buildUi() UiState {
    // Window
    const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL);
    c.gtk_window_set_title(ch.GTK_WINDOW(window), "Tsubame");
    c.gtk_window_set_default_size(ch.GTK_WINDOW(window), 1024, 768);

    // Main vertical box
    const vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0);
    c.gtk_container_add(ch.GTK_CONTAINER(window), vbox);

    // --- Toolbar ---
    const toolbar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 2);
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), toolbar, 0, 0, 0);

    const back_btn = c.gtk_button_new_with_label("\xE2\x97\x80"); // ◀
    const forward_btn = c.gtk_button_new_with_label("\xE2\x96\xB6"); // ▶
    const reload_btn = c.gtk_button_new_with_label("\xE2\x9F\xB3"); // ⟳

    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), back_btn, 0, 0, 0);
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), forward_btn, 0, 0, 0);
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), reload_btn, 0, 0, 0);

    const url_entry = c.gtk_entry_new();
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), url_entry, 1, 1, 4);

    const bookmark_btn = c.gtk_button_new_with_label("\xE2\x98\x86"); // ☆
    c.gtk_box_pack_start(ch.GTK_BOX(toolbar), bookmark_btn, 0, 0, 0);

    // --- Tab bar ---
    const tab_bar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 1);
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), tab_bar, 0, 0, 0);

    const new_tab_btn = c.gtk_button_new_with_label("+");
    c.gtk_box_pack_end(ch.GTK_BOX(tab_bar), new_tab_btn, 0, 0, 0);

    // --- Web content area (GtkStack) ---
    const web_stack = c.gtk_stack_new();
    c.gtk_stack_set_transition_type(ch.GTK_STACK(web_stack), c.GTK_STACK_TRANSITION_TYPE_NONE);
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), web_stack, 1, 1, 0);

    // --- Find bar (hidden by default) ---
    const find_bar = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 2);
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
    c.gtk_box_pack_start(ch.GTK_BOX(vbox), download_bar, 0, 0, 0);
    c.gtk_widget_set_no_show_all(download_bar, 1);

    const download_label = c.gtk_label_new("");
    c.gtk_box_pack_start(ch.GTK_BOX(download_bar), download_label, 1, 1, 4);

    return UiState{
        .window = window,
        .url_entry = url_entry,
        .tab_bar = tab_bar,
        .web_stack = web_stack,
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
