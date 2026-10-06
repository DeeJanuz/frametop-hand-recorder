#!/usr/bin/env bash
# Will these binaries run on SteamOS on the Frame? Each must be aarch64, and either static or
# needing only libraries SteamOS has, at symbol versions it has: glibc 2.39, and the libstdc++
# of GCC 13 (SteamOS 0.3 on the Frame has GCC 15's). ft-handpanel must find libopenvr_api in SteamVR.
# Usage: scripts/check-binaries.sh BINARY...
set -euo pipefail
GLIBC_MAX=2.39
GLIBCXX_MAX=3.4.32
ALLOWED=" libc.so.6 libm.so.6 libpthread.so.0 libdl.so.2 ld-linux-aarch64.so.1 libstdc++.so.6 libgcc_s.so.1
          libgbm.so.1 libdrm.so.2 libopenvr_api.so "
ALLOWED=" $(echo $ALLOWED) "   # one space between names
STEAMVR_RPATH=/opt/steamvr/bin/linuxarm64

newer() {  # is version $1 newer than $2?
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

fail=0
bad() { echo "  FAIL: $*"; fail=1; }
for bin in "$@"; do
  echo "$bin"
  [ -f "$bin" ] || { bad "missing"; continue; }
  info=$(file -b "$bin")
  case $info in *"ARM aarch64"*) ;; *) bad "not an aarch64 binary: $info"; continue ;; esac
  needed=$(readelf -d "$bin" | sed -n 's/.*(NEEDED).*\[\(.*\)\]$/\1/p')
  if [ -z "$needed" ]; then
    case $info in
      *"statically linked"*|*"static-pie linked"*) echo "  static" ;;
      *) bad "needs no libraries but isn't static: $info" ;;
    esac
  else
    for lib in $needed; do
      case $ALLOWED in *" $lib "*) ;; *) bad "needs $lib, which SteamOS may not have" ;; esac
    done
    echo "  needs: $(echo $needed)"
  fi
  syms=$(objdump -T "$bin" 2>/dev/null || true)
  glibc=$(grep -o 'GLIBC_[0-9][0-9.]*' <<<"$syms" | sed 's/GLIBC_//' | sort -uV | tail -1 || true)
  glibcxx=$(grep -o 'GLIBCXX_[0-9][0-9.]*' <<<"$syms" | sed 's/GLIBCXX_//' | sort -uV | tail -1 || true)
  if [ -n "$glibc" ]; then
    if newer "$glibc" "$GLIBC_MAX"; then bad "needs glibc $glibc (SteamOS has $GLIBC_MAX)"; else echo "  glibc symbols up to $glibc"; fi
  fi
  if [ -n "$glibcxx" ]; then
    if newer "$glibcxx" "$GLIBCXX_MAX"; then bad "needs GLIBCXX_$glibcxx (allowed up to $GLIBCXX_MAX)"; else echo "  libstdc++ symbols up to $glibcxx"; fi
  fi
  case " $needed " in
    *" libopenvr_api.so "*)
      rpath=$(readelf -d "$bin" | sed -n 's/.*(\(RUNPATH\|RPATH\)).*\[\(.*\)\]$/\2/p')
      [ "$rpath" = "$STEAMVR_RPATH" ] || bad "libopenvr_api.so is looked for in '$rpath', not $STEAMVR_RPATH"
      ;;
  esac
done
[ "$fail" = 0 ] && echo "all binaries OK for SteamOS" || { echo "some binaries won't run on SteamOS" >&2; exit 1; }
