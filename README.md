# Telegram Theme Sync

Telegram Desktop that matches your Omarchy theme and wallpaper. Automatically.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Omarchy 4](https://img.shields.io/badge/Omarchy-4-informational)

![Telegram themed by Omarchy](preview.png)

## Features

- Maps your theme's `colors.toml` to Telegram's window, chat list, bubbles, menus and buttons
- Uses the current wallpaper as the chat background (downscaled so Telegram accepts it)
- Detects light/dark themes and computes text contrast
- Reacts to theme switches and wallpaper cycling

## Install

```bash
sudo pacman -S --needed zip imagemagick inotify-tools
omarchy plugin add https://github.com/rahmatov-abdullaxon/omarchy-telegram-theme --enable
```

## One-time Telegram setup

1. **Settings → Chat Settings → Chat background → Choose from file**
2. Select `~/.local/share/omarchy-telegram/omarchy.tdesktop-theme`
3. **Apply This Theme → Keep Changes**

Don't move or delete that file. Telegram remembers the path.

## Usage

Switch themes or wallpapers as usual. Telegram relaunches with the new colors.

| Task | Command |
| --- | --- |
| Regenerate the theme file now | `omarchy-shell io.github.rahmatov-abdullaxon.telegram-theme resync` |
| Check the watcher is running | `pgrep -af omarchy-telegram-watch` |
| View logs | `journalctl --user -b --no-pager \| grep omarchy-telegram` |
| Update | `omarchy plugin update io.github.rahmatov-abdullaxon.telegram-theme` |
| Disable | `omarchy-plugin-disable io.github.rahmatov-abdullaxon.telegram-theme` |

Telegram only reads themes at launch, so it relaunches on every change. It can't hot-swap colors. If Telegram isn't running, only the theme file is regenerated.

## Troubleshooting

- **Nothing changes:** run the watcher check and the logs command above. You should see one `omarchy-telegram-watch` process.
- **Telegram ignores the theme:** redo the one-time setup and re-select the file.
- **Missing dependency:** the watcher needs `inotifywait`; the generator needs `zip` and `magick` or `convert`.

## Uninstall

```bash
omarchy plugin remove io.github.rahmatov-abdullaxon.telegram-theme
```

Then pick a built-in theme in Telegram under Settings → Chat Settings.

## License

[MIT](LICENSE) © Rahmatov Abdullaxon
