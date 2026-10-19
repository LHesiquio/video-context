# video-context — reference

Read only when needed (times, models, quality, maintenance). Daily use is in `SKILL.md`.

## Models (CPU, 8 threads, no GPU, 7 GB of RAM)

| Model | RAM (int8) | Speed | Quality | When |
|---|---|---|---|---|
| `tiny` | ~0.5 GB | very fast | poor | tests, finding out what a video is about |
| `base` | ~0.7 GB | fast | acceptable | videos over 1 hour, clean audio |
| `small` | ~1.5 GB | medium | good | **the default** |
| `medium` | ~3–4 GB | slow | very good | only if `small` fails; at the RAM limit |
| `large-*` | ~5–6 GB | not viable | — | ruled out on this machine |

The speed column holds **estimates**: measure with `bench/bench.sh` (planned, not written yet) before
quoting times to a user.

## How it works inside

```
video ──ffmpeg──► audio.wav (mono, 16 kHz, s16le) ──faster-whisper──► segments.json / transcript.md
                                          └─ vad_filter=True + word_timestamps=True
video ──ffmpeg──► sheet.jpg (fps=1/N, tile)      ← a single image for visual context
video ──ffmpeg──► frames/<second>s.jpg           ← -ss before -i: keyframe seek (~0.2 s)
```

Two Whisper settings that keep garbage out:

- `vad_filter=True`: without it, Whisper **hallucinates** plausible subtitles over music or silence.
- `word_timestamps=True`: gives the exact second per word and lets you pin a specific mention.

## Context cost for the agent

| Artifact | Typical size | Approx. tokens |
|---|---|---|
| `transcript.md` for 1 hour | ~40 KB | ~10k |
| `sheet.jpg` (4x6, 320 px tiles) | ~60 KB | ~1.5k |
| a single 512 px frame | 8–20 KB | ~0.4k |

An hour-long video can be summarised in ~12k tokens. The real limit is CPU, not the AI.

## Hard limits

- `MAX_TILES = 24` in `vt`: the contact sheet never exceeds 24 tiles; on a long video the CLI
  **raises the interval** on its own and records it in `manifest.json → sheet.interval_s` (tiles stay
  uniform: tile *k* = `first_frame_at_s + k * interval_s`).
- Timestamps in `transcript.md` are rounded to the second (for citing). Millisecond precision is in
  `segments.json`.
- No diarization: it can't tell speakers apart.
- No URL downloading: that needs `yt-dlp` (not implemented).

## Maintenance

- `vt` pins **exact** versions (`faster-whisper==1.2.1`, `av==15.1.0`) and runs with
  `uv run --script --frozen` against `vt.lock`. This isn't cosmetic: the Claude directory validation
  **blocks** `uv run` launchers with version ranges or without `--locked`/`--frozen`.
- If you change the dependencies in the PEP 723 header, regenerate the lock:
  `uv lock --script skills/video-context/vt` and commit `vt.lock` with the script.
- The old rule was `av<16`; the exact pin `av==15.1.0` is what works (av 19 breaks faster-whisper with
  `metadata_errors`).
- Self-check: `bash tests/selftest.sh` (fixture built with `espeak-ng`, no network except the first
  `tiny` model download). It must print `OK: everything passes`.
- Repo layout: `skills/video-context/vt` (CLI) and `vt.lock`, `skills/video-context/SKILL.md` and
  `reference.md` (this file), `tests/`, `output/` (generated artifacts, git-ignored).
