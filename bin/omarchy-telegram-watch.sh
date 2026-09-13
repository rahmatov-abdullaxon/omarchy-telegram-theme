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

for pid in $(pgrep -f "bash .*omarchy-telegram-watch\.sh" 2>/dev/null); do
  [[ "$pid" == "$$" ]] && continue
  kill "$pid" 2>/dev/null || true
done
sleep 0.2

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
  # Close our lock fd in the subshell before exec'ing Telegram -- otherwise
  # Telegram inherits it and holds the lock for as long as it runs (which
  # is basically forever), permanently blocking every future watcher
  # instance from ever acquiring it. Confirmed via /proc/PID/fd testing.
  if pgrep -x telegram-desktop >/dev/null 2>&1; then
    pkill -x telegram-desktop || true
    sleep 0.3
    ( exec 200>&-; setsid telegram-desktop >/dev/null 2>&1 & disown ) || true
  elif pgrep -x Telegram >/dev/null 2>&1; then
    pkill -x Telegram || true
    sleep 0.3
    ( exec 200>&-; setsid Telegram >/dev/null 2>&1 & disown ) || true
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
