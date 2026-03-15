# Tsubame

A lightweight WebKitGTK browser written in Zig. Designed to run comfortably on 512MB RAM.

## Features

- **Tab pool with LRU eviction** — bounds memory by limiting active WebViews (default: 3)
- **Bookmarks** — toggle with Ctrl+D or ☆ button, view at `tsubame://bookmarks`
- **History** — auto-recorded, view at `tsubame://history` or Ctrl+H
- **In-page search** — Ctrl+F with next/prev navigation
- **Download manager** — notification bar with auto-hide
- **Session persistence** — auto-saves every 30s, restores on restart
- **Cookie management** — persistent, no third-party cookies
- **Custom URI scheme** — `tsubame://` for internal pages

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+T | New tab |
| Ctrl+W | Close tab |
| Ctrl+Tab | Next tab |
| Ctrl+Shift+Tab | Previous tab |
| Ctrl+1-9 | Switch to tab N |
| Ctrl+L | Focus URL bar |
| Ctrl+F | Find in page |
| Ctrl+D | Toggle bookmark |
| Ctrl+H | History |
| Ctrl+R / F5 | Reload |
| Ctrl+Q | Quit |
| Alt+Left/Right | Back/Forward |
| Escape | Close find bar / Stop loading |

## Build

Requires: Zig 0.15+, GTK3, WebKitGTK 4.1, SQLite3

```bash
# Arch Linux
sudo pacman -S webkit2gtk-4.1 gtk3 sqlite

# Build
zig build

# Run
zig build run

# Release build (50KB binary)
zig build -Doptimize=ReleaseSmall
```

## Binary Size

| Build | Size |
|-------|------|
| Debug | 8.1MB |
| ReleaseFast | 2.2MB |
| ReleaseSafe | 2.4MB |
| ReleaseSmall | 50KB |

## Data

Stored in `~/.local/share/tsubame/` (XDG compliant):
- `tsubame.db` — history, bookmarks, downloads, sessions, settings
- `cookies.sqlite` — WebKit cookie storage

## Architecture

```
src/
├── main.zig          # Entry point, GTK signals, keybinds
├── c_helpers.zig     # @cImport + GTK/WebKit type cast helpers
├── browser.zig       # WebView creation, navigation, cookies
├── tabs.zig          # Tab pool with LRU eviction
├── ui.zig            # GTK widget tree construction
├── storage.zig       # SQLite operations
├── history.zig       # History CRUD + tsubame://history
├── bookmarks.zig     # Bookmark CRUD + tsubame://bookmarks
├── search.zig        # In-page find
└── downloads.zig     # Download manager
```

1,336 lines of Zig. No external Zig dependencies.

## License

MIT
