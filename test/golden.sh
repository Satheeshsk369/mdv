#!/bin/bash
cd "$(dirname "$0")/golden"
bin=${MDV:-../../build/mdv}
mode=${1:-check}
out=${TMPDIR:-/tmp}/mdv-golden
rm -rf "$out" && mkdir -p "$out"
export XDG_CONFIG_HOME="$out/config"
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
  bin=$(cd "$OLDPWD" && realpath "$bin")
  screen() {
    local name=$1 file=$2; shift 2
    tmux kill-session -t mdvgolden 2>/dev/null
    tmux new-session -d -s mdvgolden -x 100 -y 30 -e XDG_CONFIG_HOME="$XDG_CONFIG_HOME" -c "$PWD" "EDITOR=true $bin $file"
    sleep 0.5
    for k in "$@"; do
      if [ "${k:0:1}" = "!" ]; then eval "${k:1}"; sleep 0.5; else tmux send-keys -t mdvgolden "$k"; sleep 0.3; fi
    done
    tmux capture-pane -e -p -t mdvgolden > "$out/tui.$name"
  }
  screen open sample.md
  screen down sample.md Down Down Down Down
  screen up sample.md End Up Up Up
  screen half sample.md PageDown
  screen bottom sample.md End
  screen top sample.md End Home
  screen line sample.md:60
  screen goto sample.md : 4 0 Enter
  screen jumptype sample.md : 1 2
  screen search sample.md / L a T e X Enter n n
  screen searchesc sample.md / L a T e X Enter Escape
  screen searchtype sample.md / m a t
  screen nowrap sample.md w Right Right Left
  screen toc sample.md Tab
  screen tocjump sample.md Tab Down Down Enter
  screen tocbottom sample.md Tab End
  screen tocesc sample.md Tab Down Escape
  screen files ""
  screen filesopen "" Down Enter
  screen filetree sample.md o
  screen filesall sample.md o a
  screen filesleft sample.md o Down Left
  screen help sample.md "?"
  screen menu sample.md Space
  screen theme sample.md c
  screen thememove sample.md c Down Down
  screen themerevert sample.md c Down Down Escape
  screen themelast sample.md c End
  screen themekeep sample.md c Down Enter "!rm -rf $XDG_CONFIG_HOME"
  screen menuopen sample.md Space Down Enter
  screen menudirect sample.md Space "?"
  screen menuquit sample.md Space q "!echo"
  screen mark sample.md Down Down Down Down Down Down h
  screen markmove sample.md Down Down Down Down Down Down h Down Down Down
  screen edit sample.md Down Down Down E
  screen editor sample.md Down Down e
  screen editortype sample.md Down Down e End " " t y p e d
  screen editormark sample.md Down Down Down Down Down Down Down Down h e
  screen editornarrow sample.md e "!tmux resize-window -t mdvgolden -x 70 -y 30"
  screen editorwarn sample.md e x Escape
  screen editordiscard sample.md e x Escape Escape
  screen editorundo sample.md e x y Enter z C-z
  screen editormenu sample.md e C-o
  screen editormenuopen sample.md e C-o Down Down Down Enter L a T e X Enter
  screen editorpreview sample.md e C-r
  screen editornowrap sample.md Down Down e C-w End
  screen editorfind sample.md e C-f m a t h Enter C-n
  screen editorline sample.md e C-g 4 0 Enter
  screen editorlines sample.md e Down Down C-d C-k C-c Down Down C-v
  screen editorcut sample.md e Down Down C-x
  screen editorredo sample.md e x C-z C-y
  screen editorhighlight sample.md e Down Down C-h
  screen editorhighlightblock sample.md e C-g 1 1 2 Enter C-h
  screen editorhighlightoff sample.md e C-g 1 1 2 Enter C-h C-h
  screen ctrlc sample.md C-c "!echo"
  screen editorselect sample.md e Down Down S-Right S-Right S-Right S-Right S-Right S-Right S-Right
  screen editorselectlines sample.md e Down Down S-Down S-Down S-End
  screen editorselectcut sample.md e S-End C-x
  screen editorselectall sample.md e C-a
  screen editorword sample.md e Down Down C-Right C-Right C-S-Right
  screen editorlist sample.md e C-g 2 2 Enter End Enter n e w
  screen editormove sample.md e M-Down M-Down
  screen editorindent sample.md e S-Down S-Down Tab
  screen editoroutdent sample.md e Tab Tab BTab
  screen editorreplace sample.md e C-e L a T e X Enter T e X Enter
  screen editorpair sample.md e C-End "(" x ")" " " "[" a BSpace BSpace " " "\`" c
  screen editorwrapsel sample.md e S-C-Right S-C-Right "*"
  screen editormatches sample.md e C-f m d v Enter
  screen editorclick sample.md e "!tmux send-keys -t mdvgolden -l \$'\\e[<0;12;8M\\e[<0;12;8m'"
  screen editordrag sample.md e "!tmux send-keys -t mdvgolden -l \$'\\e[<0;8;5M\\e[<32;20;5M\\e[<0;20;5m'"
  screen editorpreviewclick sample.md e "!tmux send-keys -t mdvgolden -l \$'\\e[<0;60;12M'"
  cp sample.md saved.md
  screen editorsave saved.md e "#" " " C-s Escape
  rm saved.md
  screen copy sample.md y
  screen math math.md End
  screen text text.md PageDown
  cp sample.md live.md
  screen reload live.md End "!sed -i '40a NEWLINE' live.md"
  rm live.md
  screen resize sample.md "!tmux resize-window -t mdvgolden -x 70 -y 20"
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
