#!/usr/bin/env bash
# uninstall.sh -- removes the omarchy-telegram-theme hook plugin.
set -uo pipefail

rm -f "$HOME/.config/omarchy/hooks/theme-set.d/telegram-theme.sh"
rm -f "$HOME/.local/bin/omarchy-telegram-theme-gen.sh"
rm -rf "$HOME/.local/share/omarchy-telegram"

# optional watcher, if installed
systemctl --user disable --now omarchy-telegram-theme.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/omarchy-telegram-theme.service"
rm -f "$HOME/.local/bin/omarchy-telegram-watch.sh"
systemctl --user daemon-reload >/dev/null 2>&1 || true

echo "omarchy-telegram-theme: uninstalled."
echo "In Telegram, switch back to a built-in theme under Settings -> Chat Settings."
