#!/usr/bin/env bash
# install.sh -- installs the omarchy-telegram-theme hook plugin.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- sanity check: does this look like an Omarchy system? ---
if ! command -v omarchy-theme-set >/dev/null 2>&1 \
   && [[ ! -d "$HOME/.config/omarchy" ]] \
   && [[ ! -d "$HOME/.local/state/omarchy" ]]; then
  echo "omarchy-telegram-theme: this doesn't look like an Omarchy system" \
       "(no omarchy-theme-set command, no ~/.config/omarchy, no ~/.local/state/omarchy)." >&2
  echo "Aborting -- install this only on an Omarchy install." >&2
  exit 1
fi

# --- dependency check (warn, don't hard-fail; package manager varies) ---
command -v zip >/dev/null 2>&1 || \
  echo "warning: 'zip' not found -- install it (pacman -S zip) or theme generation will fail" >&2
if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  echo "warning: imagemagick not found -- wallpapers will be bundled at full size," \
       "which Telegram may silently reject if the image is large. Install with: pacman -S imagemagick" >&2
fi

# --- install the generator ---
mkdir -p "$HOME/.local/bin"
cp "$REPO_DIR/bin/omarchy-telegram-theme-gen.sh" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/omarchy-telegram-theme-gen.sh"

# --- install the native Omarchy hook ---
mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d"
cp "$REPO_DIR/hooks/telegram-theme.sh" "$HOME/.config/omarchy/hooks/theme-set.d/"
chmod +x "$HOME/.config/omarchy/hooks/theme-set.d/telegram-theme.sh"

echo "omarchy-telegram-theme: installed. Generating your first theme package..."
"$HOME/.local/bin/omarchy-telegram-theme-gen.sh"

cat <<'MSG'

Installed. One manual step left, inside Telegram (only needed once):

  Settings -> Chat Settings -> Chat background -> Choose from file
  -> select ~/.local/share/omarchy-telegram/omarchy.tdesktop-theme
  -> Apply This Theme -> Keep Changes

After that, every Omarchy theme switch (omarchy-theme-next /
omarchy-theme-set) will regenerate and reload Telegram's theme
automatically -- no daemon, no background process.

Optional: this alone won't react to cycling wallpaper *within* the same
theme (omarchy-theme-bg-next), since Omarchy's theme-set hook only fires on
a full theme switch. If you also want that, see the "Optional: live
wallpaper sync" section in README.md for a small systemd watcher.
MSG
