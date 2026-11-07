#!/bin/bash
cd "$(dirname "$0")/golden"
bin=../../build/mdv
mode=${1:-check}
out=${TMPDIR:-/tmp}/mdv-golden
rm -rf "$out" && mkdir -p "$out"
trap 'rm -rf "$out"; tmux kill-session -t mdvgolden 2>/dev/null' EXIT

for f in *.md; do
  for w in 40 80 131; do
    timeout 10 $bin "$f" -s -W $w > "$out/${f%.md}.s$w"
    timeout 10 $bin "$f" -p -W $w > "$out/${f%.md}.p$w"
    timeout 10 $bin "$f" -s -nw -W $w > "$out/${f%.md}.n$w"
    timeout 10 $bin -W $w < "$f" | cmp -s - "$out/${f%.md}.s$w" || echo "stdin differs: $f $w" >> "$out/stdin.err"
  done
done

if command -v tmux > /dev/null; then
  mkdir -p "$out/dir" && cp *.md "$out/dir" && pushd "$out/dir" > /dev/null
  bin=$(realpath "$OLDPWD/../../build/mdv")
  screen() {
    local name=$1 file=$2; shift 2
    tmux kill-session -t mdvgolden 2>/dev/null
    tmux new-session -d -s mdvgolden -x 100 -y 30 -c "$PWD" "EDITOR=true $bin $file"
    sleep 0.5
    for k in "$@"; do tmux send-keys -t mdvgolden "$k"; sleep 0.3; done
    tmux capture-pane -e -p -t mdvgolden > "$out/tui.$name"
  }
  screen open sample.md
  screen down sample.md j j j j
  screen up sample.md G k k k
  screen half sample.md d
  screen bottom sample.md G
  screen top sample.md G g
  screen line sample.md:60
  screen goto sample.md : 4 0 Enter
  screen jumptype sample.md : 1 2
  screen search sample.md / L a T e X Enter n n
  screen searchesc sample.md / L a T e X Enter Escape
  screen searchtype sample.md / m a t
  screen nowrap sample.md w l l h
  screen toc sample.md Tab
  screen tocjump sample.md Tab j j Enter
  screen tocbottom sample.md Tab G
  screen tocesc sample.md Tab j Escape
  screen files ""
  screen filesopen "" j Enter
  screen filetree sample.md o
  screen filesall sample.md o a
  screen filesleft sample.md o j h
  screen help sample.md "?"
  screen edit sample.md j j j e
  screen copy sample.md y
  screen math math.md G
  screen text text.md d
  popd > /dev/null
fi

if [ "$mode" = update ]; then
  rm -rf out && mkdir out && cp "$out"/*.s* "$out"/*.p* "$out"/*.n* out/ && cp "$out"/tui.* out/ 2>/dev/null
  echo "golden: updated $(ls out | wc -l) files"
  exit 0
fi
bad=0
[ -f "$out/stdin.err" ] && { cat "$out/stdin.err"; bad=1; }
for f in out/*; do
  cmp -s "$f" "$out/$(basename "$f")" || { echo "differs: $(basename "$f")"; bad=1; }
done
[ $bad = 0 ] && echo "golden: $(ls out | wc -l) files identical"
exit $bad
