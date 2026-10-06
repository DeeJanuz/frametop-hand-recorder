#!/usr/bin/env bash
# Install or update the Frametop Hand Recorder on a Steam Frame, without Frametop:
#   curl -fsSL https://github.com/DeeJanuz/frametop-hand-recorder/releases/latest/download/get-hand-recorder.sh | bash
# Then open it from SteamVR's dashboard: Launch a program -> Frametop Hand Recorder.
#
# It downloads this release, checks its SHA256, unpacks it into
# ~/.local/share/frametop-hand-recorder/versions/VERSION (current points at it), sets up the
# window's Python packages in a venv there (pinned with hashes), gives the camera broker ft-camd
# its permissions (sudo setcap: the one step that needs your password), and adds the menu entry.
# Running it again updates. Your recordings stay in ~/.local/share/frametop/hands/contrib.
#
# Options (after "bash -s --" when piped):
#   --uninstall     remove the install, its venv and the menu entry; recordings stay
#   --from FILE     install from a release tarball on disk instead of downloading it
#   --no-caps       skip the setcap step (the recorder then can't read the cameras)
#   --yes           don't ask before installing
set -euo pipefail

VERSION=0.0.0-dev   # the release's packaging fills this in
REPO=DeeJanuz/frametop-hand-recorder
share=${XDG_DATA_HOME:-$HOME/.local/share}
PREFIX=$share/frametop-hand-recorder
ENTRY=$share/applications/frametop-hand-recorder.desktop
DATA=$HOME/.local/share/frametop/hands/contrib   # the recorder's own default (takes.DEFAULT_BASE)
CAPS=cap_sys_ptrace,cap_perfmon,cap_dac_read_search+ep
NEED_MB=1200   # the release, the venv (PySide6 is ~300 MB) and the download, with room to spare

say() { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
ask() {  # QUESTION: true for yes. Reads the terminal, as stdin may be curl's pipe.
  [ "$yes" = 1 ] && return 0
  [ -r /dev/tty ] || die "no terminal to ask in: run it again with --yes"
  local reply
  read -r -p "$1 [Y/n] " reply </dev/tty || return 1
  case $reply in ""|y|Y|yes|Yes) return 0 ;; *) return 1 ;; esac
}

usage() {
  cat <<EOF
Frametop Hand Recorder $VERSION installer. Options (after "bash -s --" when piped from curl):
  --uninstall   remove the install, its venv and the menu entry; recordings stay
  --from FILE   install from a release tarball on disk instead of downloading this release
  --no-caps     skip the setcap step (the recorder then can't read the cameras)
  --yes         don't ask before installing
EOF
}

from="" caps=1 yes=0 action=install
while [ $# -gt 0 ]; do
  case $1 in
    --uninstall) action=uninstall ;;
    --from) [ $# -ge 2 ] || die "--from needs a file"; from=$(readlink -f "$2"); shift ;;
    --no-caps) caps=0 ;;
    --yes|-y) yes=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option $1 (see --help)" ;;
  esac
  shift
done
[ "$(id -u)" != 0 ] || die "run it as your own user, not with sudo: it asks for sudo itself, once"

# The recorder's transient units (session.py, ft_handrec.py), stopped if they run this install's
# programs: Frametop's own recorder uses the same names.
stop_units() {
  local unit
  for unit in frametop-handrec-camd.service frametop-handrec-hands.service frametop-handrec-awake.service; do
    if systemctl --user -q is-active "$unit" 2>/dev/null &&
       systemctl --user show -p ExecStart --value "$unit" 2>/dev/null | grep -qF "$PREFIX/"; then
      systemctl --user stop "$unit" && say "stopped $unit"
    fi
  done
}

if [ "$action" = uninstall ]; then
  step "Uninstalling the Frametop Hand Recorder"
  if pgrep -f "$PREFIX/versions/.*/hands/rec/ft_handrec.py" >/dev/null 2>&1; then
    die "the Hand Recorder is open: close it first"
  fi
  stop_units
  rm -f "$ENTRY" && say "removed the menu entry"
  # Deleting ft-camd takes its permissions with it: no sudo needed.
  [ -d "$PREFIX" ] && rm -rf "$PREFIX" && say "removed $PREFIX"
  say ""
  say "Your recordings are still in $DATA (Frametop's recorder uses it too):"
  say "delete that folder to remove them. Your Hugging Face login, if you made one, is in"
  say "~/.cache/huggingface/token: delete that file to log out."
  exit 0
fi

step "Checking this system"
os() {  # a key of /etc/os-release, read in a subshell (it sets VERSION too)
  (. /etc/os-release 2>/dev/null && eval "printf '%s' \"\${$1:-}\"")
}
if [ "$(os ID)" != steamos ] || [ "$(os VARIANT_ID)" != vr ]; then
  die "this is for SteamOS on the Steam Frame (this is $(os PRETTY_NAME))"
fi
[ "$(uname -m)" = aarch64 ] || die "this is for the Steam Frame's aarch64 CPU, not $(uname -m)"
[ -d /opt/steamvr/bin/linuxarm64 ] || die "SteamVR isn't in /opt/steamvr: the recorder needs it"
for tool in curl sha256sum tar python3 systemctl getcap; do
  command -v "$tool" >/dev/null || die "$tool is missing"
done
py=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
python3 -c 'import sys, venv, ensurepip; sys.exit(sys.version_info < (3, 12))' 2>/dev/null ||
  die "Python 3.12 or newer with venv is needed (found $py)"
mkdir -p "$PREFIX"
free_mb=$(df -Pm "$PREFIX" | awk 'NR == 2 {print $4}')
[ "$free_mb" -ge "$NEED_MB" ] || die "not enough free space: ${free_mb} MB free, about $NEED_MB MB needed"
say "SteamOS $(os VERSION_ID) on the Frame, Python $py, $((free_mb / 1024)) GB free"
installed=$(readlink "$PREFIX/current" 2>/dev/null | sed 's#.*/##' || true)

step "Frametop Hand Recorder $VERSION"
if [ -n "$installed" ]; then
  if [ -n "$from" ]; then say "Installed now: $installed. This replaces it with $(basename "$from")."
  else say "Installed now: $installed. This updates it to $VERSION."; fi
else
  say "It installs into $PREFIX and adds \"Frametop Hand Recorder\" to SteamVR's Launch a program."
  [ "$caps" = 0 ] || say "One step needs your password: giving the camera broker its permissions (below)."
fi
ask "Go ahead?" || die "nothing installed"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tarball=frametop-hand-recorder-$VERSION-aarch64.tar.gz
if [ -n "$from" ]; then
  step "Unpacking $from"
  [ -f "$from" ] || die "$from doesn't exist"
  cp "$from" "$work/" 2>/dev/null || die "can't read $from"
  tarball=$(basename "$from")
  sums=$(dirname "$from")/SHA256SUMS
  if [ -f "$sums" ] && grep -q " $tarball\$" "$sums"; then
    (cd "$work" && grep " $tarball\$" "$sums" | sha256sum -c --quiet -) || die "$from doesn't match $sums"
    say "checksum OK"
  else
    say "no SHA256SUMS next to it: not checked"
  fi
else
  step "Downloading"
  base=https://github.com/$REPO/releases/download/v$VERSION
  curl -fL --retry 3 --progress-bar -o "$work/$tarball" "$base/$tarball" || die "couldn't download $base/$tarball"
  curl -fsSL --retry 3 -o "$work/SHA256SUMS" "$base/SHA256SUMS" || die "couldn't download $base/SHA256SUMS"
  (cd "$work" && grep " $tarball\$" SHA256SUMS | sha256sum -c --quiet -) || die "the download's checksum is wrong: try again"
  say "checksum OK"
fi

mkdir "$work/x"
tar -C "$work/x" -xzf "$work/$tarball" || die "$tarball didn't unpack"
unpacked=$(find "$work/x" -mindepth 1 -maxdepth 1 -type d -name 'frametop-hand-recorder-*' | head -1)
[ -n "$unpacked" ] && [ -f "$unpacked/standalone.json" ] || die "$tarball isn't a Hand Recorder release"
got=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$unpacked/standalone.json")
[[ $got =~ ^[0-9A-Za-z.+-]+$ ]] || die "$tarball has a strange version: $got"
if [ -n "$from" ]; then
  VERSION=$got
elif [ "$got" != "$VERSION" ]; then
  die "the download is version $got, not $VERSION"
fi
# Before it replaces anything: the programs must load on this SteamOS. ft-camd and ft-hands are
# static; the headset panel uses SteamVR's libopenvr_api and the system's libraries, and ldd
# says "not found" for a library or a glibc version this system doesn't have.
for prog in hands/build/ft-camd hands/build/ft-hands hands/rec/build/ft-handpanel; do
  [ -x "$unpacked/$prog" ] || die "$tarball is missing $prog"
done
if command -v ldd >/dev/null; then
  missing=$(ldd "$unpacked/hands/rec/build/ft-handpanel" 2>&1 | grep 'not found' | sed 's/^[[:space:]]*//' || true)
  [ -z "$missing" ] || die "this SteamOS can't run the release's headset panel ($missing). Is SteamVR up to date?"
fi
step "Installing $VERSION"
mkdir -p "$PREFIX/versions"
stop_units
rm -rf "$PREFIX/versions/$VERSION.new"
mv "$unpacked" "$PREFIX/versions/$VERSION.new"
rm -rf "$PREFIX/versions/$VERSION"
mv "$PREFIX/versions/$VERSION.new" "$PREFIX/versions/$VERSION"
chmod -R go-w "$PREFIX/versions/$VERSION"
ln -sfn "versions/$VERSION" "$PREFIX/current"
say "installed in $PREFIX/versions/$VERSION"
# Keep the version before this one (a window still open may use it), delete older ones.
older=$(ls -1 "$PREFIX/versions" | grep -vxF "$VERSION" | grep -vxF "${installed:-}" || true)
for old in $older; do
  rm -rf "${PREFIX:?}/versions/$old" && say "removed the old version $old"
done

step "Python packages (PySide6 and huggingface_hub, about 300 MB the first time)"
venv=$PREFIX/venv
if [ -x "$venv/bin/python" ] && [ "$("$venv/bin/python" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)" != "$py" ]; then
  say "Python changed to $py: setting the venv up again"
  rm -rf "$venv"
fi
[ -x "$venv/bin/python" ] || python3 -m venv "$venv"
"$venv/bin/python" -m pip install -q --disable-pip-version-check --no-input --require-hashes --only-binary=:all: \
  -r "$PREFIX/current/requirements.txt" || die "installing the Python packages failed (see above)"
"$venv/bin/python" -c 'import PySide6.QtQuick, huggingface_hub' || die "the Python packages don't load"
say "ready"

step "The camera broker's permissions"
camd=$PREFIX/versions/$VERSION/hands/build/ft-camd
if [ "$caps" = 0 ]; then
  say "skipped (--no-caps): the recorder can't read the cameras until this runs without it"
elif getcap "$camd" | grep -q cap_sys_ptrace; then
  say "ft-camd has them already"
else
  say "ft-camd copies the headset's camera images from SteamVR's camera service (XRService),"
  say "read-only. For that it needs three capabilities: ptrace (to take a copy of XRService's"
  say "camera buffers), perfmon and dac_read_search (to find which buffer is which camera). It"
  say "drops them all once it has set up. This needs sudo, so your password:"
  if [ "$(passwd -S "$USER" 2>/dev/null | awk '{print $2}')" = NP ]; then
    say ""
    say "Your account has no password yet, so sudo can't ask for one. Set one first: run"
    say "    passwd"
    say "in this terminal, then run the install command again."
    die "no password set"
  fi
  sudo setcap "$CAPS" "$camd" </dev/tty || die "setcap failed: run the install command again to retry"
  getcap "$camd" | grep -q cap_sys_ptrace || die "ft-camd didn't get its permissions"
  say "done"
fi

step "The headset button"
if id -nG | tr ' ' '\n' | grep -qx input; then
  say "OK: in a session, press the button on the right side of the headset for next or pause,"
  say "twice to record a step again, and hold it to stop"
else
  say "You aren't in the input group, so the recorder can't read the headset's button (the"
  say "window's buttons still work). To use it: sudo usermod -aG input $USER, then restart."
fi

step "The menu entry"
mkdir -p "$(dirname "$ENTRY")"
cat > "$ENTRY.new" <<EOF
[Desktop Entry]
Type=Application
Name=Frametop Hand Recorder
GenericName=Record your hands for the hand dataset
Comment=Record, review and upload hand recordings for Frametop's open hand dataset
Exec=$PREFIX/current/bin/frametop-hand-recorder
Icon=$PREFIX/current/app/icon.png
Terminal=false
Categories=Utility;
Keywords=hands;hand tracking;dataset;record;frametop;
EOF
mv -f "$ENTRY.new" "$ENTRY"
say "added $ENTRY"

step "Done"
say "Open the dashboard in the headset, then Launch a program -> Frametop Hand Recorder."
say "Recordings go to $DATA."
say "To update, run the same command again. To uninstall:"
say "    curl -fsSL https://github.com/$REPO/releases/latest/download/get-hand-recorder.sh | bash -s -- --uninstall"
