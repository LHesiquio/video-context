#!/usr/bin/env bash
# vt self-check: no network except the first tiny-model download.
# Usage: bash tests/selftest.sh
set -euo pipefail

VT="$(cd "$(dirname "$0")/.." && pwd)/skills/video-context/vt"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "1/5 fixture: 12s video with speech (espeak-ng)"
espeak-ng -v en -s 150 -w sp.wav \
  "Hello, this is a test of the transcriber. A second sentence to get several segments."
ffmpeg -y -v error -f lavfi -i "testsrc=size=320x180:rate=10" -i sp.wav -shortest \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac fixture.mp4

echo "2/5 probe"
test "$("$VT" probe fixture.mp4 | grep -c '"duration_s"')" = 1
test "$("$VT" probe fixture.mp4 | grep -c '"audio"')" = 1

echo "3/5 transcribe (tiny, --language en)"
OUT="$WORK/out"
"$VT" transcribe fixture.mp4 --model tiny --language en --out "$OUT"
test -s "$OUT/transcript.md"
test -s "$OUT/segments.json"
test -s "$OUT/manifest.json"
python3 - "$OUT" <<'PY'
import json, sys, pathlib
d = pathlib.Path(sys.argv[1])
segs = json.loads((d / "segments.json").read_text())
assert segs, "0 segments: nothing was transcribed"
assert all(s["start"] <= s["end"] for s in segs), "inverted timestamps"
assert any(s["words"] for s in segs), "no word-level timestamps"
assert (d / "transcript.md").read_text().count("→") == len(segs)
m = json.loads((d / "manifest.json").read_text())
assert m["transcript"]["segments"] == len(segs)
print(f"   ok: {len(segs)} segments, first start {segs[0]['start']}s")
PY

echo "4/5 frames (contact sheet)"
"$VT" frames fixture.mp4 --every 3 --out "$OUT"
test -s "$OUT/sheet.jpg"
python3 -c "import json,sys; s=json.load(open('$OUT/manifest.json'))['sheet']; assert s['tiles']>=2, s"

echo "5/5 frame at an exact second"
"$VT" frame fixture.mp4 --at 5.5 --out "$OUT"
test -s "$OUT"/frames/*5.500s.jpg
if "$VT" frame fixture.mp4 --at 999 --out "$OUT" 2>/dev/null; then
  echo "FAIL: an out-of-range timestamp was accepted"; exit 1
fi

echo "OK: everything passes"
