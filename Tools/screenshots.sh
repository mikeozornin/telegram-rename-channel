#!/bin/sh
# Installs the built app on a simulator and saves a screenshot of every -state into Evidence/.
# Usage: Tools/screenshots.sh <udid> [state ...]   (default: all states, channel; group variants with -group suffix)
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
U="$1"; shift || true
APP="$HERE/build/Build/Products/Debug-iphonesimulator/ChannelRename.app"
BID=org.telegram.ChannelRenamePrototype
xcrun simctl install "$U" "$APP"
xcrun simctl status_bar "$U" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
STATES="$*"
[ -z "$STATES" ] && STATES="list.before list.menu list.after list.search list.searchEmpty chat.original chat.renamed profile.original profile.more profile.renamed rename.new rename.filled rename.edit rename.cleared forward.me forward.other"
GROUP_STATES="list.after chat.original chat.renamed profile.original profile.more profile.renamed rename.new rename.edit forward.me"
shot() { # state kind suffix
  xcrun simctl terminate "$U" $BID >/dev/null 2>&1 || true
  xcrun simctl launch "$U" $BID -state "$1" -kind "$2" >/dev/null
  sleep 3
  xcrun simctl io "$U" screenshot "$HERE/Evidence/$1$3.png" >/dev/null 2>&1
  echo "$HERE/Evidence/$1$3.png"
}
for s in $STATES; do shot "$s" channel ""; done
if [ -z "$NO_GROUP" ]; then
  for s in $GROUP_STATES; do case " $STATES " in *" $s "*) shot "$s" group "-group";; esac; done
fi
