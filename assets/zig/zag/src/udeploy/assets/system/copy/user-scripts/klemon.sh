#!/usr/bin/env bash
set -euo pipefail

PORT=2489

sudo -v

selected="$(
  sudo ss -H -ltnp "sport = :$PORT" |
    awk '
      match($0, /pid=[0-9]+/) {
        pid = substr($0, RSTART + 4, RLENGTH - 4)
        print pid "  " $0
      }
    ' |
    sort -u |
    fzf --prompt="kill port 2489 > "
)"

[[ -n "$selected" ]] || exit 0

pid="$(awk '{print $1}' <<< "$selected")"

echo "Killing PID $pid on port $PORT..."
sudo kill "$pid"

echo "Done."
