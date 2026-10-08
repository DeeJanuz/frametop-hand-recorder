#!/usr/bin/env bash
# Put a release together in dist/, after scripts/build.sh:
#   frametop-hand-recorder-VERSION-aarch64.tar.gz  the install tree (below)
#   get-hand-recorder.sh                           the installer, for that VERSION
#   SHA256SUMS                                     of both
# The tree keeps Frametop's layout (hands/build/, hands/rec/, hands/models/), so the recorder's
# paths work as they are, with standalone.json at the top (frametop/hands/rec/takes.py's
# standalone()), this repo's window in app/ and the launcher in bin/.
# VERSION: the first argument, else the tag on HEAD (vX.Y.Z), else 0.0.0-dev+COMMIT.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ft=$root/frametop/hands
built=$root/build/hands
REINSTALL="run the Hand Recorder's install command again (github.com/Frametop/frametop-hand-recorder)"

version=${1:-}
if [ -z "$version" ]; then
  tag=$(git -C "$root" describe --tags --exact-match 2>/dev/null || true)
  case $tag in
    v[0-9]*) version=${tag#v} ;;
    *) version=0.0.0-dev+$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown) ;;
  esac
fi
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$ ]] || { echo "bad version: $version" >&2; exit 1; }
for b in build/ft-camd build/ft-hands rec/build/ft-handpanel; do
  [ -x "$built/$b" ] || { echo "$built/$b is missing: scripts/build.sh first" >&2; exit 1; }
done

name=frametop-hand-recorder-$version
dist=$root/dist
stage=$dist/$name
rm -rf "$dist"
mkdir -p "$stage"
put() {  # MODE SOURCE DEST (in the tree)
  install -D -m "$1" "$2" "$stage/$3"
}

# The binaries
put 755 "$built/build/ft-camd" hands/build/ft-camd
put 755 "$built/build/ft-hands" hands/build/ft-hands
put 755 "$built/rec/build/ft-handpanel" hands/rec/build/ft-handpanel
# Frametop's recorder: the Python it runs, its texts, script and pose pictures, and the models
put 644 "$ft/camcheck.py" hands/camcheck.py
for f in ft_handrec.py session.py takes.py sides.py hub.py validate.py script.json CONSENT.md UPLOAD.md; do
  put 644 "$ft/rec/$f" "hands/rec/$f"
done
put 644 "$ft/rec/poses/poses.json" hands/rec/poses/poses.json
for f in "$ft"/rec/poses/*.png; do
  [ "$(basename "$f")" = contact-sheet.png ] || put 644 "$f" "hands/rec/poses/$(basename "$f")"
done
for f in "$ft"/models/ncnn/*.param "$ft"/models/ncnn/*.bin; do
  put 644 "$f" "hands/models/ncnn/$(basename "$f")"
done
put 644 "$ft/models/NOTICE" hands/models/NOTICE
put 644 "$ft/camd/LICENSE.FrameEyeCameraFeed" licenses/LICENSE.FrameEyeCameraFeed
# This repo: the window, the launcher, the installer, the Python requirements and the texts
for f in "$root"/app/*; do
  put 644 "$f" "app/$(basename "$f")"
done
put 755 "$root/bin/frametop-hand-recorder" bin/frametop-hand-recorder
for f in requirements.txt LICENSE README.md THIRD-PARTY.md; do
  put 644 "$root/$f" "$f"
done
sed "s/^VERSION=.*/VERSION=$version/" "$root/get-hand-recorder.sh" > "$dist/get-hand-recorder.sh"
put 755 "$dist/get-hand-recorder.sh" get-hand-recorder.sh

frametop=$(git -C "$root/frametop" describe --always --tags --dirty 2>/dev/null || echo unknown)
python3 - "$stage/standalone.json" "$version" "$frametop" "$REINSTALL" <<'EOF'
import json, sys
path, version, frametop, reinstall = sys.argv[1:]
with open(path, "w") as f:
    json.dump({"name": "frametop-hand-recorder", "version": version, "frametop": frametop,
               "reinstall": reinstall}, f, indent=1)
    f.write("\n")
EOF

# Reproducible: the files' times are the commit's, owned by root, in name order
epoch=${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct 2>/dev/null || date +%s)}
tar -C "$dist" --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$epoch" \
  -cf - "$name" | gzip -n -9 > "$dist/$name-aarch64.tar.gz"
rm -rf "$stage"
(cd "$dist" && sha256sum "$name-aarch64.tar.gz" get-hand-recorder.sh > SHA256SUMS)
echo "packaged $version (frametop $frametop):"
ls -l "$dist"
