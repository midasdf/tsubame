# Tsubame

[![Zig](https://img.shields.io/badge/Zig-0.15+-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/Platform-Linux-yellow?logo=linux&logoColor=white)](https://kernel.org)

A lightweight WebKitGTK browser written in Zig. Designed to run comfortably on 512MB RAM.

## Features

- **Tab pool with LRU eviction** — bounds memory by limiting active WebViews (default: 3, configurable)
- **Bookmarks** — toggle with Ctrl+D or ☆ button, view at `tsubame://bookmarks`
- **History** — auto-recorded, view at `tsubame://history` or Ctrl+H
- **In-page search** — Ctrl+F with next/prev navigation
- **Download manager** — notification bar with auto-hide
- **Session persistence** — auto-saves every 30s, restores on restart
- **Cookie management** — persistent, no third-party cookies
- **Ad blocking** — built-in WebKit content filter rules (togglable)
- **Private browsing** — Ctrl+Shift+N opens ephemeral tab (no cookies/history)
- **User scripts** — drop `.js` files in `~/.local/share/tsubame/scripts/`
- **Split view** — Ctrl+\ splits the window horizontally
- **Dark theme** — Catppuccin Mocha-inspired dark UI by default
- **Config file** — `~/.local/share/tsubame/config` (key=value format)
- **Custom URI scheme** — `tsubame://` for internal pages

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+T | New tab |
| Ctrl+W | Close tab |
| Ctrl+Shift+N | New private tab |
| Ctrl+Tab | Next tab |
| Ctrl+Shift+Tab | Previous tab |
| Ctrl+1-9 | Switch to tab N |
| Ctrl+L | Focus URL bar |
| Ctrl+F | Find in page |
| Ctrl+D | Toggle bookmark |
| Ctrl+H | History |
| Ctrl+\ | Toggle split view |
| Ctrl+R / F5 | Reload |
| Ctrl+Q | Quit |
| Alt+Left/Right | Back/Forward |
| Escape | Close find bar / Stop loading |

## Configuration

Create `~/.local/share/tsubame/config`:

```ini
# Max active (non-suspended) tabs
max_active_tabs = 3

# Homepage
homepage = https://duckduckgo.com

# Ad blocking (true/false)
adblock_enabled = true
```

## User Scripts

Drop any `.js` file into `~/.local/share/tsubame/scripts/` and it will be injected into all pages at document-end (Greasemonkey-style).

## Build

Requires: Zig 0.15+, GTK3, WebKitGTK 4.1, SQLite3

```bash
# Arch Linux
sudo pacman -S webkit2gtk-4.1 gtk3 sqlite

# Build & run
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
- `scripts/` — user scripts (*.js)
- `content-filters/` — compiled ad block rules
- `config` — settings file

## Architecture

```
src/
├── main.zig          # Entry point, GTK signals, keybinds
├── c_helpers.zig     # @cImport + GTK/WebKit type cast helpers
├── browser.zig       # WebView creation, navigation, cookies
├── tabs.zig          # Tab pool with LRU eviction
├── ui.zig            # GTK widget tree + dark theme CSS
├── storage.zig       # SQLite operations
├── config.zig        # Config file parser
├── history.zig       # History CRUD + tsubame://history
├── bookmarks.zig     # Bookmark CRUD + tsubame://bookmarks
├── search.zig        # In-page find
├── downloads.zig     # Download manager
├── adblock.zig       # WebKit content filter ad blocking
├── private.zig       # Ephemeral WebView for private browsing
└── userscript.zig    # User script loader
```

1,927 lines of Zig. 14 modules. No external Zig dependencies.

## License

MIT

## Disclaimer
This project uses AI-generated code (LLM). I do my best to review and test it, but I can't guarantee it's perfect. Please use it at your own risk.\n