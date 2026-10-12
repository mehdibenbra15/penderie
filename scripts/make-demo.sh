#!/bin/zsh
# Re-renders docs/demo.gif, docs/demo.mp4 and docs/hero.png from scripts/demo/main.swift.
# Needs ffmpeg (brew install ffmpeg).
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/frames" docs
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos26.0" \
  Sources/Rack.swift Sources/RackView.swift scripts/demo/main.swift -o "$WORK/demo"
"$WORK/demo" "$WORK"
cp "$WORK/hero.png" docs/hero.png
ffmpeg -loglevel error -y -f concat -safe 0 -i "$WORK/frames/list.txt" \
  -vf "fps=30,scale=1200:-2:flags=lanczos,format=yuv420p" -c:v libx264 -crf 18 -movflags +faststart docs/demo.mp4
ffmpeg -loglevel error -y -f concat -safe 0 -i "$WORK/frames/list.txt" \
  -vf "fps=20,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -loop 0 docs/demo.gif
ls -lh docs
