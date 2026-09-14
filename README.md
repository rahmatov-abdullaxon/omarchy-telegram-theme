# omarchy-telegram-theme

Keeps Telegram Desktop's colors and chat background in sync with your active
Omarchy theme and wallpaper — automatically, on every theme switch.

Telegram Desktop has one hard limitation this whole project works around: it
does **not** hot-swap colors while running. A theme loaded via *Settings →
Chat background → Choose from file* is re-read only when the app launches
(confirmed in Telegram's own docs). So every install method below does the
same thing underneath: regenerate the `.tdesktop-theme` file, then relaunch
Telegram. A quick relaunch, not an in-place color fade — that's the ceiling
of what Telegram's architecture allows.

## Pick ONE install method, not both

Both do the same job through different plumbing. Installing both means two
independent processes race to regenerate and restart Telegram on the same
event.

| | Native Omarchy plugin | Manual hook + optional watcher |
|---|---|---|
| Install via | `omarchy plugin add` | `./install.sh` |
| Background process | Yes (Quickshell-supervised) | No, unless you add the optional watcher |
| Reacts to a full theme switch | Yes | Yes |
| Reacts to wallpaper-only cycling | Yes | Only with the optional watcher |
| Status | **Extensively tested live** against a real running Omarchy session, including a real crash-loop bug found and fixed (see CHANGELOG.md) | Generator logic is well-tested in isolation; the `install.sh` / hook / systemd path itself has not been run against a live Omarchy install |

Not sure which to pick: the native plugin tier is the better-proven path
today.

## Option A: Native Omarchy plugin (omarchyplugins.com / `omarchy plugin` CLI)

`manifest.json` + `Service.qml` sit at the repo root. `Service.qml` is a
headless `service`-kind entry point that supervises `bin/omarchy-telegram-watch.sh`
as a child process — no logic reimplemented in QML, it just launches and
monitors the same tested bash script.

An earlier version also shipped `BarWidget.qml` (a bar icon for one-click
resync). It was dropped: a bar widget can't reliably hold a live reference to
another plugin's service object, so the click action had no solid way to
actually trigger anything. Use the terminal command below instead — one
line, always works.

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

**Status of the QML, honestly:** the process-supervision and restart-retry
logic (`Service.qml` relaunching the watcher after it exits) has been
confirmed live, including recovering correctly from a real crash-loop bug —
see CHANGELOG.md. The `omarchy-shell <id> resync` IPC path has **not** been
confirmed the same way: its `IpcHandler` target binds to a value computed
from the async-loaded plugin manifest, and nothing here has verified that
binding is still live by the time you'd call it. If it silently does
nothing, check `qs log -p "$OMARCHY_PATH/shell" --tail 100` first.

## Option B: Manual hook + optional watcher

Drop a script into Omarchy's own `~/.config/omarchy/hooks/theme-set.d/` —
Omarchy already runs every script there on every theme switch, so this adds
zero background processes.

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

If nothing happens when you try to open the file, check the gotchas below
before assuming it's broken — a couple of failure modes here are completely
silent.

Uninstall any time with `./uninstall.sh`.

### Optional: also react to wallpaper-only cycling

Omarchy's theme-set hook only fires on a full theme switch, not on
`omarchy-theme-bg-next`. To also catch that:

```bash
mkdir -p ~/.config/systemd/user
cp systemd/omarchy-telegram-theme.service ~/.config/systemd/user/
cp bin/omarchy-telegram-watch.sh ~/.local/bin/
chmod +x ~/.local/bin/omarchy-telegram-watch.sh
systemctl --user daemon-reload
systemctl --user enable --now omarchy-telegram-theme.service
```

Event-driven (`inotifywait`, no polling), near-zero idle CPU/RAM. Requires
`inotify-tools`. Telegram launches inside this service's cgroup, so
`systemctl --user stop` also closes Telegram (`systemctl --user restart` is
fine). Add `KillMode=process` to the unit's `[Service]` block if you want to
pause the watcher without closing Telegram.

## What it does

- Reads your active theme's `colors.toml` and maps ~90 of Telegram's real
  theme variables to it — window chrome, chat list, message bubbles, compose
  bar, menus, buttons, tooltips.
- Understands two different Omarchy `colors.toml` schemas seen in the wild:
  a named-hue one (`accent`, `muted`, `selection`, `dark_background` /
  `lighter_background` / `darker_background`, `red`/`green`/`yellow`/...)
  and an older ANSI one (`color0`-`color15`, `selection_background`). Prefers
  whichever named keys your theme provides and falls back to computed shades
  otherwise.
- Auto-detects light vs. dark and computes text contrast dynamically rather
  than assuming which of your two base colors is "light".
- Grabs whatever wallpaper is *currently* active, downscales it to a
  sensible size, and bundles it in as the chat background.
- Packages it all into a real `.tdesktop-theme` file.

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
- **A kill-based single-instance guard is a race, not a fix.** The watcher
  went through three real design iterations before landing on a
  non-blocking `flock` with no killing at all. Full story, and why it's
  non-blocking rather than blocking, in CHANGELOG.md — read that before
  touching the lock logic again.

## Requirements

```bash
sudo pacman -S --needed zip imagemagick   # inotify-tools only needed for the optional watcher
```

## Other known rough edges

- **Path auto-detection**: Omarchy sources disagree on whether the active
  theme lives under `~/.config/omarchy/current/theme` or
  `~/.local/state/omarchy/current/theme`. Both scripts check both.
- **Partial variable coverage**: Telegram has ~300 theme constants; this
  maps the ~90 that cover what you actually look at.
- **Resync IPC timing unconfirmed** — see the honesty note under Option A.

## Publishing this yourself

Fork or copy this repo, then anyone can install with:

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

## Uninstall

```bash
./uninstall.sh
```
Then in Telegram, switch back to a built-in theme under Settings → Chat
Settings.

Native plugin tier: `omarchy plugin remove <id>` (verb not verified in this
repo — check `omarchy plugin --help` for the current one).
