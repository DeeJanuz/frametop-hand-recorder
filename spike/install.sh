#!/usr/bin/env bash
# Add (or with --remove, take away) two entries to SteamVR's "Launch a program" for testing in
# the headset, both from this checkout:
#   "Hand Recorder spike"            spike/run.sh (spike.py: what works in the dashboard)
#   "Hand Recorder (dev, dry run)"   the real window, bin/frametop-hand-recorder --dry-run
#                                    --hub-dry-run, with its own scratch folder (build/dev-base),
#                                    so no session starts anything and nothing is uploaded
# Needs the checkout's venv: python3 -m venv .venv && .venv/bin/pip install --require-hashes
# -r requirements.txt
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
apps=$HOME/.local/share/applications
spike=$apps/frametop-hand-recorder-spike.desktop
dev=$apps/frametop-hand-recorder-dev.desktop
if [ "${1:-}" = --remove ]; then
  rm -f "$spike" "$dev"
  echo "removed the spike's menu entries"
  exit 0
fi
[ -x "$root/.venv/bin/python" ] || { echo "no venv in $root/.venv (see the comment at the top)" >&2; exit 1; }
mkdir -p "$apps" "$root/build/dev-base"
cat > "$spike" <<EOT
[Desktop Entry]
Type=Application
Name=Hand Recorder spike
Comment=What works in SteamVR's dashboard (frametop-hand-recorder/spike)
Exec=$root/spike/run.sh
Icon=$root/app/icon.png
Terminal=false
Categories=Utility;
EOT
cat > "$dev" <<EOT
[Desktop Entry]
Type=Application
Name=Hand Recorder (dev, dry run)
Comment=The standalone recorder's window from the checkout, in a dry run
Exec=$root/bin/frametop-hand-recorder --dry-run --hub-dry-run --base $root/build/dev-base
Icon=$root/app/icon.png
Terminal=false
Categories=Utility;
EOT
echo "added $spike"
echo "added $dev"
