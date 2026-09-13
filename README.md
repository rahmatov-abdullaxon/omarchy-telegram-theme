# omarchy-telegram-theme

Keeps Telegram Desktop's colors and chat background in sync with your active
Omarchy theme and wallpaper — automatically. Built and battle-tested against
a real Omarchy install.

## Two tiers

**Core plugin (recommended default):** a single script dropped into
Omarchy's own `~/.config/omarchy/hooks/theme-set.d/` hook directory —
Omarchy already runs every script there on every theme switch, so this adds
**zero background processes**. Switch themes with `omarchy-theme-next` /
`omarchy-theme-set` and Telegram updates automatically.

**Optional extra:** Omarchy's theme-set hook only fires on a full theme
switch, not on `omarchy-theme-bg-next` (cycling wallpaper within the same
theme). If you also want Telegram to react to that, there's a small
systemd watcher service you can layer on top — see below.

## Native Omarchy plugin (omarchyplugins.com / `omarchy plugin` CLI)

This repo doubles as a real Omarchy 4 plugin: `manifest.json` +
`Service.qml` + `BarWidget.qml` sit at the repo root alongside the
standalone scripts. `Service.qml` is a headless `service`-kind entry point
that supervises the same tested `bin/omarchy-telegram-watch.sh` as a child
process (no reimplementation); `BarWidget.qml` adds an optional bar icon
you can click to force an immediate resync.

**Honesty note:** the manifest and file layout are mechanically validated
against the real schema rules from `omarchy-plugins/docs/`. The QML itself
is built from actual running code (Okomart's `Service.qml`), not guessed —
but I have no Quickshell runtime to execute it in, so unlike every bash
script in this repo, it has not actually been run. Please run
`omarchy plugin validate ./` yourself, test it, and treat the restart-retry
logic and IPC target-matching as best-effort until confirmed.

Before installing, edit `manifest.json`: replace `YOUR_USERNAME` in `id`
and `YOUR_NAME` in `author`.

```bash
omarchy plugin validate .
omarchy plugin source add <your-repo-url> --as tg
omarchy plugin available
omarchy plugin add tg.telegram-theme --from tg --review --enable
```

Or locally without publishing first:
```bash
omarchy plugin add /path/to/this/checkout --review --enable
```

Force a manual resync any time with:
```bash
omarchy-shell <your-plugin-id> resync
```

## Standalone (non-marketplace) install

## Read this first: the one real limitation

Telegram Desktop does **not** support hot-swapping colors while it's
running. A theme loaded via *Settings → Chat background → Choose from file*
is **re-read only when the app launches** (confirmed in Telegram's own
docs). So both tiers work by regenerating the theme file and restarting
Telegram — a quick relaunch, not an in-place color fade. That's the ceiling
of what Telegram's architecture allows.

## What it does

- Reads your active theme's `colors.toml` and maps ~90 of Telegram's real
  theme variables to it — window chrome, chat list, message bubbles, compose
  bar, menus, buttons, tooltips.
- Understands two different Omarchy `colors.toml` schemas seen in the wild:
  a named-hue one (`accent`, `muted`, `selection`, `dark_background` /
  `lighter_background` / `darker_background`, `red`/`green`/`yellow`/...)
  and an older ANSI one (`color0`-`color15`, `selection_background`). It
  prefers whichever named keys your theme provides and falls back to
  computed shades otherwise.
- Auto-detects light vs. dark and computes text contrast dynamically rather
  than assuming which of your two base colors is "light".
- Grabs whatever wallpaper is *currently* active, downscales it to a
  sensible size, and bundles it in as the chat background.
- Packages it all into a real `.tdesktop-theme` file.

## Install (core plugin)

```bash
git clone <your-repo-url> omarchy-telegram-theme
cd omarchy-telegram-theme
./install.sh
```

This installs the generator to `~/.local/bin/`, the hook to
`~/.config/omarchy/hooks/theme-set.d/telegram-theme.sh`, and runs it once.

**One-time step inside Telegram:** Settings → Chat Settings → Chat background
→ **Choose from file** → select
`~/.local/share/omarchy-telegram/omarchy.tdesktop-theme`, then **Apply This
Theme** → **Keep Changes**. You only do this once — Telegram remembers the
path and reloads it on every future launch. Don't delete or move this file
afterward.

If nothing happens when you try to open the file, see the gotchas below
before assuming it's broken — a couple of failure modes here are completely
silent.

Uninstall any time with `./uninstall.sh`.

## Optional: live wallpaper sync

To also react to `omarchy-theme-bg-next` (not just full theme switches):

```bash
mkdir -p ~/.config/systemd/user
cp systemd/omarchy-telegram-theme.service ~/.config/systemd/user/
cp bin/omarchy-telegram-watch.sh ~/.local/bin/
chmod +x ~/.local/bin/omarchy-telegram-watch.sh
systemctl --user daemon-reload
systemctl --user enable --now omarchy-telegram-theme.service
```

This runs a lightweight `inotifywait`-based watcher (near-zero idle CPU/RAM
— it's event-driven, not polling) that additionally catches wallpaper
cycling. Requires `inotify-tools`. Note: Telegram launches inside this
service's cgroup, so `systemctl --user stop` also closes Telegram
(`systemctl --user restart` is fine). Add `KillMode=process` to the unit's
`[Service]` block if you want to pause the watcher without closing Telegram.

## Gotchas actually hit while building this (all now handled by the script)

- **Telegram silently rejects oversized theme packages.** An 11MB
  4000×2250 PNG wallpaper caused the whole `.tdesktop-theme` import to do
  nothing — no error, no popup, just silence. A ~100KB 1920px-wide JPEG
  worked instantly. The generator auto-downscales via `magick`/`convert`
  before bundling (falls back to full size with a warning if neither is
  installed).
- **`;`-prefixed comment lines break the parser.** Telegram's
  `colors.tdesktop-theme` format does not support `;` comments — a single
  such line made Telegram reject the entire file silently.
- **`colors.toml` schema varies between themes.** Handled via fallback
  chains, see above.
- **The Linux binary name isn't consistent.** Some installs ship it as
  `telegram-desktop`, others simply as `Telegram` (capital T). Both scripts
  try both names.
- **Omarchy discards a hook's stdout.** The hook script sends everything to
  stderr so `journalctl`/manual runs can still see it.

## Requirements

```bash
sudo pacman -S --needed zip imagemagick   # inotify-tools only needed for the optional watcher
```

## Publishing this for other Omarchy users

I can't push to GitHub on your behalf, but this directory is ready to go:

```bash
cd /path/to/omarchy-telegram-theme
git init
git add .
git commit -m "omarchy-telegram-theme: sync Telegram Desktop with Omarchy themes"
git branch -M main
git remote add origin git@github.com:<you>/omarchy-telegram-theme.git
git push -u origin main
```

Then anyone can install with:
```bash
git clone https://github.com/<you>/omarchy-telegram-theme && cd omarchy-telegram-theme && ./install.sh
```

If you want it listed in the community `thpm` plugin manager
(github.com/OldJobobo/thpm) instead of just standalone, note that it's grown
into a full Python application with its own plugin contract and test suite
— getting an integration merged there means following their
`CONTRIBUTING.md`/`AGENTS.md` process directly with that project's
maintainers. This repo is a solid reference implementation to adapt from if
you decide to pursue that.

## Other known rough edges

- **Path auto-detection**: Omarchy sources disagree on whether the active
  theme lives under `~/.config/omarchy/current/theme` or
  `~/.local/state/omarchy/current/theme`. Both scripts check both.
- **Partial variable coverage**: Telegram has ~300 theme constants; this
  maps the ~90 that cover what you actually look at.

## Uninstall

```bash
./uninstall.sh
```
Then in Telegram, switch back to a built-in theme under Settings → Chat
Settings.
