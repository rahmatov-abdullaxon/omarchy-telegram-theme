#!/usr/bin/env bash
# omarchy-telegram-theme-gen.sh
#
# Reads the currently active Omarchy theme (colors.toml + current wallpaper)
# and builds a Telegram Desktop custom theme package (.tdesktop-theme, which
# is just a zip containing colors.tdesktop-theme + a background image).
#
# Run standalone any time to regenerate, or let omarchy-telegram-watch.sh
# call it automatically on theme/wallpaper changes.

set -euo pipefail

OUT_DIR="${OMARCHY_TG_OUT_DIR:-$HOME/.local/share/omarchy-telegram}"
OUT_FILE="$OUT_DIR/omarchy.tdesktop-theme"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------------------
# Locate the active theme directory. Omarchy docs/tools disagree on whether
# this currently lives under ~/.config/omarchy/current/theme or
# ~/.local/state/omarchy/current/theme — we check both and use whichever
# actually has a colors.toml, so this keeps working either way.
# ---------------------------------------------------------------------------
find_theme_dir() {
  local p
  for p in "$HOME/.config/omarchy/current/theme" "$HOME/.local/state/omarchy/current/theme"; do
    if [[ -e "$p/colors.toml" ]]; then
      readlink -f "$p"
      return 0
    fi
  done
  return 1
}

THEME_DIR="$(find_theme_dir)" || {
  echo "omarchy-telegram: couldn't find colors.toml under ~/.config/omarchy/current/theme" \
       "or ~/.local/state/omarchy/current/theme -- edit find_theme_dir() if your Omarchy uses a different path." >&2
  exit 1
}
COLORS_FILE="$THEME_DIR/colors.toml"

# ---------------------------------------------------------------------------
# Locate the current wallpaper: prefer the live "current/background" symlink
# (which omarchy-theme-bg-next rotates), fall back to the first image in the
# theme's backgrounds/ folder.
# ---------------------------------------------------------------------------
find_background() {
  local p
  for p in "$HOME/.config/omarchy/current/background" "$HOME/.local/state/omarchy/current/background"; do
    if [[ -e "$p" ]]; then
      readlink -f "$p"
      return 0
    fi
  done
  local bgdir="$THEME_DIR/backgrounds"
  if [[ -d "$bgdir" ]]; then
    find "$bgdir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort | head -n1
  fi
}

BG_PATH="$(find_background || true)"

# ---------------------------------------------------------------------------
# Minimal TOML reader (colors.toml is a flat key = "value" file, no need for
# a real parser).
# ---------------------------------------------------------------------------
# Never lets a missing key kill the script (some themes define a color0..15
# palette, others use named hues like `red`/`green` -- either is fine).
toml_get() {
  local key="$1" val
  val="$(grep -E "^${key}[[:space:]]*=" "$COLORS_FILE" 2>/dev/null | head -n1 \
    | sed -E 's/^[a-zA-Z0-9_]+[[:space:]]*=[[:space:]]*"?([^"[:space:]]+)"?.*/\1/')" || true
  printf '%s' "$val"
}

# ---------------------------------------------------------------------------
# Tiny hex color math (pure bash, no bc/python dependency), used as a
# fallback when a theme doesn't provide its own surface/status colors.
# ---------------------------------------------------------------------------
hex2rgb() { # $1=#RRGGBB -> sets R G B
  local h="${1#\#}"
  R=$((16#${h:0:2})); G=$((16#${h:2:2})); B=$((16#${h:4:2}))
}
mix() { # mix hexA toward hexB by ratio 0-100 -> echoes #RRGGBB
  local a="$1" b="$2" ratio="$3" ar ag ab br bg bb
  hex2rgb "$a"; ar=$R; ag=$G; ab=$B
  hex2rgb "$b"; br=$R; bg=$G; bb=$B
  printf '#%02x%02x%02x' \
    $(( (ar*(100-ratio) + br*ratio) / 100 )) \
    $(( (ag*(100-ratio) + bg*ratio) / 100 )) \
    $(( (ab*(100-ratio) + bb*ratio) / 100 ))
}
luma() { hex2rgb "$1"; echo $(( (R*299 + G*587 + B*114) / 1000 )); } # $1=#RRGGBB -> 0-255
abs_diff() { local a=$1 b=$2; echo $(( a>b ? a-b : b-a )); }
# Given a background color, pick whichever of the theme's own FG/BG colors
# contrasts against it more -- works regardless of whether the theme calls
# itself light or dark, and needs no dedicated "selection_foreground" key.
contrast_of() {
  local bgh="$1" l_bg l_fg l_base d1 d2
  l_bg="$(luma "$bgh")"; l_fg="$(luma "$FG")"; l_base="$(luma "$BG")"
  d1="$(abs_diff "$l_bg" "$l_fg")"; d2="$(abs_diff "$l_bg" "$l_base")"
  if (( d1 >= d2 )); then printf '%s' "$FG"; else printf '%s' "$BG"; fi
}

# --- required base colors (same key names across every schema seen so far) ---
ACCENT="$(toml_get accent)"
FG="$(toml_get foreground)"
BG="$(toml_get background)"
: "${ACCENT:?missing 'accent' in $COLORS_FILE}"
: "${FG:?missing 'foreground' in $COLORS_FILE}"
: "${BG:?missing 'background' in $COLORS_FILE}"

# --- light/dark: prefer an explicit `mode = "light"` key, fall back to a
#     light.mode marker file, default to dark ---
MODE_KEY="$(toml_get mode)"
IS_LIGHT=0
if [[ "$MODE_KEY" == "light" ]]; then IS_LIGHT=1
elif [[ -f "$THEME_DIR/light.mode" ]]; then IS_LIGHT=1
fi

# --- muted/secondary text: named `muted` key, else bright-black (color8),
#     else black (color0), else a computed shade ---
MUTED="$(toml_get muted)"
[[ -z "$MUTED" ]] && MUTED="$(toml_get color8)"
[[ -z "$MUTED" ]] && MUTED="$(toml_get color0)"
if [[ -z "$MUTED" ]]; then
  if [[ "$IS_LIGHT" -eq 1 ]]; then MUTED="$(mix "$FG" "$BG" 40)"; else MUTED="$(mix "$FG" "$BG" 45)"; fi
fi

# --- elevated surface colors: prefer the theme's own named variants,
#     else fall back to computed mixes ---
SURFACE="$(toml_get lighter_background)"
DEEP_BG="$(toml_get dark_background)"
DEEPER_BG="$(toml_get darker_background)"
SELECTION="$(toml_get selection)"
[[ -z "$SELECTION" ]] && SELECTION="$(toml_get selection_background)"

if [[ "$IS_LIGHT" -eq 1 ]]; then
  [[ -z "$SURFACE" ]] && SURFACE="$(mix "$BG" "#000000" 5)"
  [[ -z "$DEEP_BG" ]] && DEEP_BG="$(mix "$BG" "#000000" 4)"
  [[ -z "$DEEPER_BG" ]] && DEEPER_BG="$(mix "$BG" "#000000" 8)"
  [[ -z "$SELECTION" ]] && SELECTION="$(mix "$BG" "#000000" 12)"
else
  [[ -z "$SURFACE" ]] && SURFACE="$(mix "$BG" "#ffffff" 7)"
  [[ -z "$DEEP_BG" ]] && DEEP_BG="$(mix "$BG" "#000000" 5)"
  [[ -z "$DEEPER_BG" ]] && DEEPER_BG="$(mix "$BG" "#000000" 10)"
  [[ -z "$SELECTION" ]] && SELECTION="$(mix "$BG" "#ffffff" 14)"
fi
SURFACE2="$SELECTION"

# --- text colors that need to contrast against a computed/theme background,
#     instead of assuming a dedicated selection_foreground key exists ---
SEL_TEXT="$(contrast_of "$SELECTION")"
ACCENT_TEXT="$(contrast_of "$ACCENT")"

# --- status hues: named (red/green/yellow) else ANSI (color1/2/3) ---
RED="$(toml_get red)";    [[ -z "$RED" ]] && RED="$(toml_get color1)"
GREEN="$(toml_get green)"; [[ -z "$GREEN" ]] && GREEN="$(toml_get color2)"

# ---------------------------------------------------------------------------
# Write colors.tdesktop-theme. Variable names are the real Telegram Desktop
# theme constants (see https://github.com/telegramdesktop/tdesktop/wiki/Theme-Reference).
# This intentionally covers the ~90 constants that drive what you actually
# see (window chrome, chat list, bubbles, compose bar, menus, buttons) and
# leaves everything else at Telegram's own default, rather than guessing at
# the full ~300-constant set.
# ---------------------------------------------------------------------------
PALETTE="$WORK_DIR/colors.tdesktop-theme"
cat > "$PALETTE" <<EOF
windowBg: ${BG};
windowBgOver: ${SURFACE};
windowBgActive: ${SURFACE2};
windowBgRipple: ${SURFACE2};
windowFg: ${FG};
windowFgActive: ${FG};
windowFgOver: ${FG};
windowBoldFg: ${FG};
windowBoldFgOver: ${ACCENT};
windowSubTextFg: ${MUTED};
windowSubTextFgOver: ${MUTED};
windowActiveTextFg: ${ACCENT};
windowShadowFg: ${DEEPER_BG};
windowShadowFgFallback: ${DEEPER_BG};

titleBg: ${DEEP_BG};
titleBgActive: ${DEEP_BG};
titleFg: ${MUTED};
titleFgActive: ${FG};
titleButtonBg: ${DEEP_BG};
titleButtonBgOver: ${SURFACE};
titleButtonFg: ${MUTED};
titleButtonFgOver: ${FG};
titleButtonCloseBg: ${DEEP_BG};
titleButtonCloseBgOver: ${RED};
titleButtonCloseFg: ${MUTED};
titleButtonCloseFgOver: ${FG};

dialogsBg: ${BG};
dialogsBgOver: ${SURFACE};
dialogsBgActive: ${SURFACE2};
dialogsNameFg: ${FG};
dialogsNameFgActive: ${FG};
dialogsNameFgOver: ${FG};
dialogsTextFg: ${MUTED};
dialogsTextFgActive: ${FG};
dialogsTextFgOver: ${MUTED};
dialogsTextFgService: ${ACCENT};
dialogsTextFgServiceActive: ${ACCENT};
dialogsDateFg: ${MUTED};
dialogsDateFgActive: ${FG};
dialogsDraftFg: ${RED};
dialogsDraftFgActive: ${RED};
dialogsUnreadBg: ${ACCENT};
dialogsUnreadBgActive: ${ACCENT};
dialogsUnreadBgMuted: ${MUTED};
dialogsUnreadFg: ${ACCENT_TEXT};
dialogsUnreadFgActive: ${ACCENT_TEXT};
dialogsSentIconFg: ${ACCENT};
dialogsSentIconFgActive: ${ACCENT};
dialogsVerifiedIconBg: ${ACCENT};
dialogsVerifiedIconFg: ${ACCENT_TEXT};
dialogsMenuIconFg: ${MUTED};
dialogsMenuIconFgOver: ${FG};
dialogsChatIconFg: ${MUTED};
dialogsChatIconFgActive: ${FG};
dialogsForwardBg: ${SURFACE2};
dialogsForwardFg: ${FG};

historyTextInFg: ${FG};
historyTextOutFg: ${SEL_TEXT};
msgInBg: ${SURFACE};
msgInBgSelected: ${SURFACE2};
msgOutBg: ${SELECTION};
msgOutBgSelected: ${SURFACE2};
msgInServiceFg: ${ACCENT};
msgOutServiceFg: ${SEL_TEXT};
msgInDateFg: ${MUTED};
msgOutDateFg: ${SEL_TEXT};
msgInReplyBarColor: ${ACCENT};
msgOutReplyBarColor: ${SEL_TEXT};
msgInMonoFg: ${ACCENT};
msgOutMonoFg: ${SEL_TEXT};
msgServiceBg: ${SURFACE2};
msgServiceFg: ${MUTED};
msgSelectOverlay: ${ACCENT}33;
msgStickerOverlay: ${BG}66;
layerBg: ${BG}CC;
mediaviewBg: ${BG}F2;
mediaviewTextLinkFg: ${ACCENT};

historyComposeAreaBg: ${SURFACE};
historyComposeAreaFg: ${FG};
historyComposeAreaFgService: ${MUTED};
historyComposeIconFg: ${MUTED};
historyComposeIconFgOver: ${ACCENT};
historySendIconFg: ${ACCENT};
historySendIconFgOver: ${ACCENT};
placeholderFg: ${MUTED};
placeholderFgActive: ${MUTED};
activeLineFg: ${ACCENT};
activeLineFgError: ${RED};

activeButtonBg: ${ACCENT};
activeButtonBgOver: ${ACCENT};
activeButtonBgRipple: ${SELECTION};
activeButtonFg: ${ACCENT_TEXT};
activeButtonFgOver: ${ACCENT_TEXT};
lightButtonBg: ${SURFACE2};
lightButtonBgOver: ${SURFACE2};
lightButtonFg: ${ACCENT};
attentionButtonBgOver: ${RED};
attentionButtonFg: ${ACCENT_TEXT};

boxBg: ${SURFACE};
boxTextFg: ${FG};
boxTitleFg: ${FG};
boxSearchBg: ${SURFACE2};
boxTextFgError: ${RED};
boxTextFgGood: ${GREEN};
menuBg: ${SURFACE};
menuBgOver: ${SURFACE2};
menuIconFg: ${MUTED};
menuIconFgOver: ${FG};
scrollBg: ${SURFACE};
scrollBgOver: ${SURFACE2};
scrollBarBg: ${MUTED};
scrollBarBgOver: ${FG};

topBarBg: ${BG};
tooltipBg: ${SURFACE2};
tooltipFg: ${FG};
tooltipBorderFg: ${SURFACE2};
toastBg: ${SURFACE2}CC;
toastFg: ${FG};
notificationBg: ${BG};

trayCounterBg: ${RED};
trayCounterFg: ${ACCENT_TEXT};
trayCounterBgMute: ${MUTED};

introBg: ${BG};
introTitleFg: ${FG};
introDescriptionFg: ${MUTED};
EOF

# ---------------------------------------------------------------------------
# Bundle the current wallpaper as the chat background (non-tiled, Telegram
# will scale/crop it like a normal wallpaper). Downscaled to 1920px wide --
# Telegram's theme importer silently rejects the whole package if the image
# is too large (confirmed: an 11MB/4000x2250 PNG failed with no error at all,
# a ~1920px JPEG a few hundred KB worked fine).
# ---------------------------------------------------------------------------
if [[ -n "${BG_PATH:-}" && -f "$BG_PATH" ]]; then
  OUT_IMG="$WORK_DIR/background.jpg"
  if command -v magick >/dev/null 2>&1; then
    magick "$BG_PATH" -resize '1920x1920>' -quality 85 "$OUT_IMG" 2>/dev/null
  elif command -v convert >/dev/null 2>&1; then
    convert "$BG_PATH" -resize '1920x1920>' -quality 85 "$OUT_IMG" 2>/dev/null
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -loglevel error -i "$BG_PATH" -vf "scale='min(1920,iw)':-2" "$OUT_IMG" 2>/dev/null
  fi
  if [[ ! -s "$OUT_IMG" ]]; then
    # no resize tool available / resize failed -- fall back to a raw copy,
    # but warn since a very large original may cause Telegram to reject it
    echo "omarchy-telegram: warning: no image resizer found (install imagemagick or ffmpeg)," \
         "bundling wallpaper at full size -- Telegram may silently reject it if it's large" >&2
    ext="${BG_PATH##*.}"
    case "${ext,,}" in
      png) cp "$BG_PATH" "$WORK_DIR/background.png" ;;
      *)   cp "$BG_PATH" "$OUT_IMG" ;;
    esac
  fi
fi

# ---------------------------------------------------------------------------
# Package as .tdesktop-theme (which is just a zip).
# ---------------------------------------------------------------------------
( cd "$WORK_DIR" && zip -q -X -r "$OUT_FILE.zip" . )
mv -f "$OUT_FILE.zip" "$OUT_FILE"

echo "omarchy-telegram: wrote $OUT_FILE (theme: $(basename "$THEME_DIR"))"
