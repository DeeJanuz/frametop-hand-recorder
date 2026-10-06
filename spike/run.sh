#!/usr/bin/env bash
# Start the dashboard spike (spike.py) with this checkout's venv (.venv), as the recorder's
# launcher starts the window: X11 through Xwayland, output to the log when there's no terminal.
here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
logdir=${XDG_STATE_HOME:-$HOME/.local/state}/frametop-hand-recorder
mkdir -p "$logdir"
[ -t 2 ] || exec >>"$logdir/spike.out" 2>&1
[ -n "${QT_QPA_PLATFORM:-}" ] || { [ -n "${DISPLAY:-}" ] && export QT_QPA_PLATFORM=xcb; }
exec "$here/../.venv/bin/python" "$here/spike.py" "$@"
