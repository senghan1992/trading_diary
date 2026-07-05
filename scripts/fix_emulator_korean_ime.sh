#!/usr/bin/env bash
# Fix Android emulator Korean IME so that hardware keyboard (Mac) input
# is routed through the IME for proper Korean syllable composition.
#
# Without this fix, `show_ime_with_hard_keyboard=0` causes the emulator
# to bypass Gboard's IME for physical keyboards — Korean keystrokes
# arrive as raw keycodes and 자음/모음 appear broken in TextFields.
#
# Usage:  bash scripts/fix_emulator_korean_ime.sh [adb-path]
#   Default adb path: /opt/homebrew/share/android-commandlinetools/platform-tools/adb

set -euo pipefail

ADB="${1:-/opt/homebrew/share/android-commandlinetools/platform-tools/adb}"

if ! command -v "$ADB" >/dev/null 2>&1; then
  echo "adb not found at $ADB. Pass your adb path as an argument."
  exit 1
fi

DEVICES=$("$ADB" devices | awk 'NR>1 && /device$/ {print $1}')
if [ -z "$DEVICES" ]; then
  echo "No running emulator/device. Launch one first (flutter emulators --launch <id>)."
  exit 1
fi

echo "Applying Korean IME fix to: $DEVICES"
"$ADB" shell settings put secure show_ime_with_hard_keyboard 1
"$ADB" shell settings put secure default_input_method com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME

# Gboard subtype ID for 한국어(두벌식). Look up via:
#   adb shell dumpsys input_method | grep -B1 "한국어(두벌식)"
"$ADB" shell settings put secure selected_input_method_subtype -1906255757

echo ""
echo "After fix:"
echo "  show_ime_with_hard_keyboard = $($ADB shell settings get secure show_ime_with_hard_keyboard)"
echo "  default_input_method        = $($ADB shell settings get secure default_input_method)"
echo "  selected subtype            = $($ADB shell settings get secure selected_input_method_subtype)"
