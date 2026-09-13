#!/usr/bin/env bash
# telegram-theme.sh
#
# Omarchy theme-set.d hook: regenerates the Telegram Desktop theme to match
# the newly active Omarchy theme/wallpaper, then restarts Telegram (if it's
# running) so it picks up the change immediately.
#
# Installed by install.sh into:
#   ~/.config/omarchy/hooks/theme-set.d/telegram-theme.sh
#
# Omarchy runs every executable script in that directory whenever the theme
# changes (omarchy-theme-set / omarchy-theme-next), so this needs no daemon,
# no systemd unit, and no inotify -- Omarchy itself is the trigger.
#
# Note: Omarchy discards a hook's stdout, so anything worth seeing goes to
# stderr. This script never exits non-zero on failure -- one broken
# integration should not block Omarchy's other theme-set.d hooks from
# running (matching the convention used by thpm and similar tools).

set -uo pipefail

GEN="$HOME/.local/bin/omarchy-telegram-theme-gen.sh"

if [[ ! -x "$GEN" ]]; then
  echo "omarchy-telegram-theme: generator not found or not executable at $GEN" >&2
  exit 0
fi

if ! "$GEN" >&2; then
  echo "omarchy-telegram-theme: generation failed, leaving the previous Telegram theme in place" >&2
  exit 0
fi

if pgrep -x telegram-desktop >/dev/null 2>&1; then
  pkill -x telegram-desktop || true
  sleep 0.3
  ( setsid telegram-desktop >/dev/null 2>&1 & disown ) || true
elif pgrep -x Telegram >/dev/null 2>&1; then
  pkill -x Telegram || true
  sleep 0.3
  ( setsid Telegram >/dev/null 2>&1 & disown ) || true
fi
# If Telegram isn't running, do nothing -- it picks up the fresh theme file
# on its own next launch, since Telegram only re-reads a linked custom theme
# at startup (not while running).

exit 0
