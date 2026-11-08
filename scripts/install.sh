#!/bin/sh
set -e
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) name=linux-x64 ;;
  Linux-aarch64 | Linux-arm64) name=linux-arm64 ;;
  Darwin-arm64) name=macos-arm64 ;;
  Darwin-x86_64) name=macos-x64 ;;
  *) echo "mdv: no release for $(uname -s) $(uname -m); build from source: https://github.com/Satheeshsk369/mdv" >&2; exit 1 ;;
esac
dir="$HOME/.local/bin"
mkdir -p "$dir"
curl -fsSL "https://github.com/Satheeshsk369/mdv/releases/latest/download/mdv-$name.tar.gz" | tar xz -C "$dir" mdv
echo "mdv installed to $dir/mdv"
case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "add $dir to PATH" ;;
esac
