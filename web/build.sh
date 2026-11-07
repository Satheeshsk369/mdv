#!/bin/sh
set -e
cd "$(dirname "$0")/.."
mkdir -p build/web
out=build/web/index.html
sed -n '1,/^__WASM__$/p' web/index.html | sed '$d' > "$out"
base64 < build/web.wasm | tr -d '\n' >> "$out"
sed -n '/^__WASM__$/,/^__DOC__$/p' web/index.html | sed '1d;$d' >> "$out"
base64 < README.md | tr -d '\n' >> "$out"
sed -n '/^__DOC__$/,$p' web/index.html | sed '1d' >> "$out"
echo "web: $out ($(wc -c < "$out") bytes)"
