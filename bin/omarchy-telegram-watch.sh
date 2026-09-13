#!/usr/bin/env bash
# omarchy-telegram-watch.sh
#
# Watches Omarchy's active theme (theme-switch) and wallpaper
# (omarchy-theme-bg-next / manual wallpaper cycling) for changes, and on
# each change regenerates the Telegram theme package and relaunches
# Telegram so it picks up the new file.
#
# IMPORTANT LIMITATION: Telegram Desktop only re-reads a "Choose from file"
# theme when it *launches* -- there is no in-place hot color swap while it
# keeps running. This script gets you as close to "live" as Telegram
# actually allows: it notices a theme/wallpaper change and restarts
# Telegram within well under a second, rather than you having to remember
# to do it yourself. It will still be a quick relaunch, not an invisible
# color fade.

set -euo pipefail

# Sweep away any leftover instances from a previous shell/plugin reload.
# `omarchy restart shell` (and plugin update/enable cycles) do not appear
# to clean up this script's already-running children -- confirmed via
# `lslocks` showing 19+ orphaned, permanently-blocked instances piling up
# across a single debugging session. Rather than depend on the host's
# lifecycle behavior, each new instance kills any older siblings itself.
for pid in $(pgrep -f "bash .*omarchy-telegram-watch\.sh" 2>/dev/null); do
  [[ "$pid" == "$$" ]] && continue
  kill "$pid" 2>/dev/null || true
done
sleep 0.2

# Refuse to run more than one instance at once. Blocking on purpose: a
# second instance just waits quietly for the lock instead of bailing with
# exit 0 and getting relaunched every 5s forever by the QML restart handler
# -- and if the active instance ever dies, the waiting one takes over
# immediately instead of nothing running at all.
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/omarchy-telegram-watch.lock"
exec 200>"$LOCKFILE"
flock 200

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$SCRIPT_DIR/omarchy-telegram-theme-gen.sh"

WATCH_DIRS=()
for p in "$HOME/.config/omarchy/current" "$HOME/.local/state/omarchy/current"; do
  [[ -d "$p" ]] && WATCH_DIRS+=("$p")
done

if [[ ${#WATCH_DIRS[@]} -eq 0 ]]; then
  echo "omarchy-telegram-watch: no ~/.config/omarchy/current (or state equivalent) found, exiting" >&2
  exit 1
fi

if ! command -v inotifywait >/dev/null 2>&1; then
  echo "omarchy-telegram-watch: inotifywait not found -- install inotify-tools" \
       "(sudo pacman -S inotify-tools, or omarchy-pkg-add inotify-tools)" >&2
  exit 1
fi

restart_telegram() {
  if pgrep -x telegram-desktop >/dev/null 2>&1; then
    pkill -x telegram-desktop || true
    sleep 0.3
    ( setsid telegram-desktop >/dev/null 2>&1 & disown ) || true
  elif pgrep -x Telegram >/dev/null 2>&1; then
    pkill -x Telegram || true
    sleep 0.3
    ( setsid Telegram >/dev/null 2>&1 & disown ) || true
  fi
}

apply() {
  bash "$GEN" && restart_telegram
}

apply

inotifywait -m -e create,delete,modify,moved_to,attrib "${WATCH_DIRS[@]}" 2>/dev/null |
while read -r _; do
  sleep 0.4
  while read -r -t 0.1 _; do :; done
  apply
done
