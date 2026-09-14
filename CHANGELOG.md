# Changelog

## 1.2.0

- **Removed:** the manual hook / `install.sh` / `uninstall.sh` / systemd-unit
  tier entirely. The native Omarchy plugin (this repo's actual submission
  target) is the only supported install path now — it's the one that's
  been tested live, and shipping two independent ways to do the same job
  was a needless second surface (they'd race each other if both were ever
  installed at once).
- **Hardened:** the watcher's lock file no longer falls back to a bare
  `/tmp/omarchy-telegram-watch.lock` if `XDG_RUNTIME_DIR` is unset. That's
  a predictable, shared path — on a multi-user machine, another local user
  could pre-create it (e.g. as a symlink) before this script ever runs.
  Falls back to a UID-namespaced directory created with mode 700 instead.

## 1.1.0

- **Fixed:** the watcher's single-instance guard was a kill race, not a real
  lock. Two instances launched close together would SIGTERM each other; each
  kill registered as a crash to the Quickshell supervisor, which respawned
  into the same race — a perpetual crash loop. Confirmed live via `qs log`
  showing repeated `watcher exited (code 15), restarting in 5s`. Replaced
  the kill-sweep + blocking `flock` with a single non-blocking `flock -n`: a
  duplicate instance now exits immediately and cleanly instead of fighting
  the real one.
- **Fixed:** `omarchy-telegram-theme-gen.sh` crashed with a raw
  `zip: command not found` (exit 127) on its very last line if `zip` was
  missing — after already doing all the TOML-parsing and image-resizing
  work. It now checks for `zip` up front and fails with a clear message.
- **Removed:** `BarWidget.qml` and the `bar-widget` manifest kind. A bar
  widget can't reliably hold a live reference to another plugin's service
  object, so the click-to-resync action had no solid way to actually
  trigger anything. Use `omarchy-shell <id> resync` instead.

## Design note: why the watcher's lock is non-blocking, not blocking

This went through three iterations. Recording the reasoning so nobody
"fixes" it back into something worse:

1. **v1 — non-blocking, exit-and-get-respawned.** A duplicate just exited.
   Harmless, but logged "restarting in 5s" forever if duplicates kept
   appearing.
2. **v2 — blocking `flock`.** A duplicate queued silently instead of
   exiting, and took over instantly if the active instance died — quieter,
   faster failover. Looked like a strict improvement over v1.
3. **The problem with v2:** a queued, blocking instance holds its resources
   open until it either wins the lock or is killed. `lslocks` showed 19+
   permanently-blocked instances piling up in one debugging session. The
   actual cause was a separate fd leak (below) — Telegram inheriting the
   lock fd and holding it open indefinitely, so the lock never actually
   freed. A kill-sweep was added on top of the blocking lock to clean up
   the pile-up, but the sweep itself raced with the lock acquisition —
   which is the crash loop fixed in 1.1.0.
4. **v3 — non-blocking, no kill-sweep (current).** Once the fd leak was
   fixed, blocking-vs-non-blocking became a real tradeoff rather than
   blocking being a strict win: something outside this script keeps
   spawning duplicate watchers on a live system, confirmed recurring rather
   than a one-off (cause unconfirmed — likely a Quickshell/plugin-host
   reload behavior, not this repo's code). A blocking design queues an
   unbounded, ever-growing pile of waiting processes against a supply of
   duplicates that never stops. A non-blocking design bounds resource use
   at exactly one duplicate's worth, in exchange for periodic harmless log
   noise. Given duplicates are a recurring background phenomenon here,
   bounded resource use wins.

## 1.0.x (native plugin bring-up)

- Fixed a real fd leak: `restart_telegram()` exec'd Telegram without first
  closing fd 200 (the lock fd), so Telegram inherited and held the lock open
  for as long as it ran — permanently blocking every future watcher
  instance. Confirmed via `/proc/PID/fd`.
- Added the single-instance lock in the first place, after observing
  duplicate watchers fighting over Telegram.
- Fixed `BarWidget.qml` `ToolTip`/`moduleName` issues and `sourceDir`
  derivation, before the widget was ultimately dropped in 1.1.0.
- Restored the executable bit; call the generator via `bash` explicitly.

## 1.0.0

- Initial plugin: core hook + generator script, optional systemd watcher,
  native Omarchy plugin wrapper.
