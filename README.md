# video-context

Turns **local video or audio** into context an AI agent (Claude Code, OpenCode, Codex…) can actually
use: a transcript with exact minutes and the **frame at a given second**, including whatever is on
screen. With that, the agent summarises, pulls out requirements and decisions, and builds what you ask
for — a diagram, a canvas, a data model — citing the minute for every claim.

No API, nothing uploaded anywhere, **no cost**: everything runs on your CPU with
[ffmpeg](https://ffmpeg.org/) + [faster-whisper](https://github.com/SYSTRAN/faster-whisper).

```
video ──ffmpeg──► 16 kHz audio ──Whisper──► transcript.md with minutes + segments.json (ms)
                                        └► sheet.jpg (the whole video in one image)
                                        └► frames/<second>.jpg (on demand)
```

This is what the agent sees, with nobody explaining anything to it:

```markdown
# interview.mp4 — 01:12:30 · en · small/int8

## 00:12:04 → 00:12:19
…and that's where the architecture part comes in, which is what I wanted to talk about today.
```

Typical use: *"summarise this video"* → the agent reads the transcript, looks at `sheet.jpg` for visual
context, and **pulls an individual frame only when the text mentions something visible** (a slide, a
schema, code on screen). An hour-long video is summarised in about 12k tokens.

On the same video you can ask for:

- **A summary, minutes or meeting notes** with the minute of each point.
- **Requirements, decisions and action items** out of a meeting or a class.
- **Diagrams** (Mermaid), **canvases** or **data models**, using the literal names from the schema when
  it appears on screen.
- **Screenshots** of a slide or a code fragment, at the exact second.

Whatever the video doesn't say and no frame shows doesn't exist: the agent is instructed not to invent
table, field or endpoint names.

## Requirements

| What | Why |
|---|---|
| `ffmpeg` and `ffprobe` | all the video and audio work |
| `uv` | `vt` installs its Python dependencies in an isolated environment (PEP 723). **It downloads `faster-whisper` and `av` from PyPI the first time** (exact versions, pinned in `vt.lock`); after that it works offline |
| ~1.5 GB of disk and RAM | the `small` model on first run (~500 MB download) |

Check: `ffmpeg -version && uv --version`.

**Privacy:** your video and audio **never leave your machine**. The only network traffic is the Python
packages (PyPI) and the Whisper model (Hugging Face) on first run.

## Install

**As a Claude Code plugin:**

```
/plugin marketplace add LHesiquio/video-context
/plugin install video-context@video-context
```

**As a skill** (Claude Code, OpenCode, or any agent that reads `SKILL.md`):

```bash
git clone https://github.com/LHesiquio/video-context ~/video-context
ln -s ~/video-context/skills/video-context ~/.claude/skills/video-context
ln -s ~/video-context/skills/video-context ~/.config/opencode/skills/video-context
```

**Just the CLI**, if you don't want skills or plugins:

```bash
ln -s ~/video-context/skills/video-context/vt ~/.local/bin/vt
```

## Usage

```bash
vt probe video.mp4                      # duration, fps, streams
vt transcribe video.mp4 --language en   # → transcript.md + segments.json + manifest.json
vt frames video.mp4                     # → sheet.jpg: the whole video in one image
vt frame video.mp4 --at 12:34.5         # → the frame at that exact second
```

| Option | What for |
|---|---|
| `--model tiny\|base\|small\|medium` | `small` by default; `base` for long videos, `medium` if `small` isn't good enough |
| `--language en` | pin the language; without it, it's autodetected (and an intro jingle can fool it) |
| `--out DIR` | where the artifacts go (default `./output/<video-name>`) |
| `--every 15` | seconds between contact-sheet tiles |

It takes anything `ffmpeg` can read: `mp4`, `mkv`, `webm`, `mov`, and plain audio (`mp3`, `m4a`, `wav`).

### What it writes to disk

| File | Contents |
|---|---|
| `transcript.md` | text with `## HH:MM:SS → HH:MM:SS` per block — the content of the video |
| `segments.json` | the same as machine data, with float seconds and **word-level** timestamps |
| `manifest.json` | duration, model, detected language, sheet parameters, paths |
| `sheet.jpg` | the video as a mosaic: tile *k* is the second `first_frame_at_s + k × interval_s` |
| `frames/` | the individual frames you asked for |

## Honest limits

- The AI doesn't "watch" the video: it sees text and whichever frames get extracted.
- Speed figures are estimates: measure on your machine before promising times. On an 8-thread CPU with
  no GPU, an hour of audio with `small` is in the 5–15 minute range.
- Loud music, several people talking at once, or heavy accents with `tiny` → a poor transcript.
- No diarization (it can't tell speakers apart) and no URL downloading (`yt-dlp` isn't included).
- DRM: no. Not happening.

## Self-check

```bash
bash tests/selftest.sh   # should print: OK: everything passes
```

It builds a test video with `espeak-ng` (no downloads), transcribes it, renders the contact sheet,
extracts one frame, and verifies every artifact. The first run downloads the `tiny` model.

## Layout

```
.claude-plugin/            plugin manifest and marketplace catalog
skills/video-context/      SKILL.md (what the agent reads) + reference.md + vt + vt.lock
tests/selftest.sh          end-to-end self-check
```

The CLI lives **inside** the skill folder on purpose, so a symlink or an installed plugin is
self-contained: `SKILL.md` refers to `vt` as "the one next to me", with no absolute paths.

## License

MIT. Whisper is MIT and the models are free; `faster-whisper` uses CTranslate2.
