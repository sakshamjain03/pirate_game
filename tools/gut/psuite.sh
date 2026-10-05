#!/usr/bin/env bash
# Needs worktrees .claude/worktrees/m30-verify-1..4, each with an UNCOMMITTED project.godot edit setting
# config/use_custom_user_dir=true + a distinct config/custom_user_dir_name, so shards never share user://.
# Usage: psuite.sh <commit-sha> — full GUT suite split over 4 isolated worktrees (own user:// each).
SHA="$1"; N=4
G=/d/Pirate-game/.godot-tools/Godot_v4.3-stable_win64_console.exe
ROOT=/d/Pirate-game/.claude/worktrees
LOG="${TMPDIR:-/tmp}/pirate_psuite"
mkdir -p "$LOG"; rm -f "$LOG"/*.log
for i in $(seq 1 $N); do
  git -C "$ROOT/m30-verify-$i" checkout -q --detach "$SHA" || exit 2
done
for i in $(seq 1 $N); do ( timeout 600 "$G" --headless --import --path "$ROOT/m30-verify-$i" >/dev/null 2>&1 ) & done; wait
# Round-robin over files sorted by size (largest first) to balance the shards.
mapfile -t FILES < <(cd "$ROOT/m30-verify-1/tests" && ls -S *.gd)
declare -a SH
for idx in "${!FILES[@]}"; do s=$(( idx % N + 1 )); SH[$s]+="res://tests/${FILES[$idx]},"; done
START=$(date +%s)
for i in $(seq 1 $N); do
  ( cd "$ROOT/m30-verify-$i" && timeout 900 "$G" --headless --path . -s addons/gut/gut_cmdln.gd "-gtest=${SH[$i]%,}" -gexit > "$LOG/shard$i.log" 2>&1; echo "exit=$?" >> "$LOG/shard$i.log" ) &
done
wait
END=$(date +%s)
tp=0; tf=0; ts=0; te=0
for i in $(seq 1 $N); do
  L="$LOG/shard$i.log"
  s=$(grep -E "^Scripts" "$L" | grep -oE "[0-9]+" | tail -1); t=$(grep -E "^Tests " "$L" | grep -oE "[0-9]+" | tail -1)
  p=$(grep -E "^\s+Passing" "$L" | grep -oE "[0-9]+" | tail -1); f=$(grep -E "^\s+Failing" "$L" | grep -oE "[0-9]+" | tail -1)
  e=$(grep -c "SCRIPT ERROR" "$L"); x=$(grep -oE "exit=[0-9]+" "$L")
  echo "shard$i scripts=${s:-?} tests=${t:-?} pass=${p:-?} fail=${f:-0} script_errors=$e $x"
  ts=$((ts+${s:-0})); tp=$((tp+${p:-0})); tf=$((tf+${f:-0})); te=$((te+e))
  grep -E "\[Failed\]" -B6 "$L" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^res://|\* test|\[Failed\]" | head -12 | sed 's/^/    /'
done
echo "TOTAL scripts=$ts pass=$tp fail=$tf script_errors=$te wall=$((END-START))s sha=$SHA"
