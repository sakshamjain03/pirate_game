#!/usr/bin/env bash
# Usage: ptest.sh <project-dir> test_a test_b ...   — runs GUT files in parallel, one line each.
P="$1"; shift
G=/d/Pirate-game/.godot-tools/Godot_v4.3-stable_win64_console.exe
OUT=$(mktemp -d)
for t in "$@"; do
  ( timeout 400 "$G" --headless --path "$P" -s addons/gut/gut_cmdln.gd -gtest=res://tests/$t.gd -gexit > "$OUT/$t.log" 2>&1 ) &
done
wait
for t in "$@"; do
  L="$OUT/$t.log"
  pass=$(grep -E "^\s*Passing" "$L" | tail -1 | grep -oE "[0-9]+")
  fail=$(grep -E "^\s*Failing" "$L" | tail -1 | grep -oE "[0-9]+")
  errs=$(grep -c "SCRIPT ERROR" "$L")
  printf "%-40s pass=%-4s fail=%-4s script_errors=%s\n" "$t" "${pass:-?}" "${fail:-0}" "$errs"
  grep -E "\[Failed\]|Parse Error" "$L" | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -6 | sed 's/^/    /'
done
rm -rf "$OUT"
