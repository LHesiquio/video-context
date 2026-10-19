---
name: video-context
description: "Turns a video, audio file, class, interview, meeting or demo into context the agent can use: a transcript with exact minutes and frames at the precise second (including whatever is on screen). Use it whenever the user brings a video/audio or asks, from it, to summarise, transcribe, find a topic, extract requirements or decisions, or build a diagram, a canvas, a data model, notes or a plan."
---

# video-context

Turns a video into **text with timestamps** + **exact frames**, using the local CLI `vt`
(ffmpeg + faster-whisper, CPU, no API, no cost). You never run ffmpeg by hand: you run `vt` and then
**read the artifacts**.

## What this is actually for

The video stops being a video and becomes **working material** with citable minutes and captures of the
exact instant. Whatever is asked from there, you build it, with the transcript as the source of truth
and the frames as visual evidence:

| The user asks for | Where it comes from |
|---|---|
| A summary, minutes, notes, a script | `transcript.md` (with minutes) |
| Requirements, decisions, action items, agreements | `transcript.md`; cite the minute of each one |
| A flow, architecture or mind map (Mermaid) | `transcript.md` for the steps; `vt frame` if a diagram is on screen |
| A canvas (business model, Lean, user journey) | `transcript.md` + `sheet.jpg` for the visuals |
| A data model / SQL schema / API | `transcript.md`; **if the schema is on screen, pull the frame and copy the real names** |
| "What is minute 14 about?" | `transcript.md` (blocks) and `vt frame --at 14:00` |
| A capture of a slide or of code | `vt frame` at the second the transcript points to |

Two rules that separate a good result from an invented one:

- **Don't invent names.** If the diagram or the schema appears on screen, extract the frame and use the
  literal names (tables, fields, endpoints) instead of plausible-sounding ones you made up.
- **Every claim gets its minute.** `12:34` is the difference between a summary and a source.

For technical material use at least `--model small`: with `tiny` you lose proper nouns, acronyms and
numbers, and that's where false requirements and diagrams come from.

## Rule number one

**Never improvise `ffmpeg`, `whisper` or `pip install` commands.** Everything goes through the `vt` CLI,
which lives **in this same folder, next to this SKILL.md**. The examples below write plain `vt`: if it
isn't on the `PATH`, replace `vt` with the absolute path `<path to this SKILL.md>/vt` (for example
`~/.claude/skills/video-context/vt` or `~/.config/opencode/skills/video-context/vt`). Check it once with
`ls -l <path>/vt` and use that path in every command.

## Workflow

### 1. Inspect (always)

```bash
vt probe video.mp4
```

It gives you `duration_s`, `fps`, `video`, `audio`. If `audio` is `null` there's nothing to transcribe:
say so.

### 2. Transcribe

```bash
# pin the language if you know it: otherwise an intro jingle can drag detection to another language
vt transcribe video.mp4 --language en
vt transcribe video.mp4 --model base --language en   # over 1 hour, or in a hurry
vt transcribe audio.mp3 --language en                # plain audio works too
```

- Default model is `small` (the sweet spot on an 8-thread CPU with no GPU). Use `tiny`/`base` for long
  videos or when you only need the gist; `medium` only if `small` quality is poor (it's slow).
- **The first run downloads the model** (~500 MB for `small`): it takes a while. Run it in the
  background (`background=true`) and carry on; don't kill it thinking it hung.
- Transcription on CPU is **slower than real time**: for 1 hour of audio allow 5–15 minutes with
  `base`/`small`. Tell the user before launching it on a long video.

### 3. Read the output (cheap; in this order)

Everything lands in `./output/<slug>/` (or wherever `--out` says):

| File | What it is | How to read it |
|---|---|---|
| `transcript.md` | text with `## HH:MM:SS → HH:MM:SS` per block | **read it in full**; it's the content of the video |
| `segments.json` | the same plus `start`/`end` as float seconds and **word-level** timestamps | only when you need sub-second precision |
| `manifest.json` | duration, model, detected language, sheet parameters, paths | check it when in doubt |
| `sheet.jpg` | **a single image** with the whole video as a mosaic | **look at it** for visual context |
| `frames/` | individual frames already extracted | — |

Check the `language` in `manifest.json`. If it isn't the real language, redo it with an explicit
`--language`: a transcript in the wrong language is garbage.

### 4. Visual context (only when it adds something)

```bash
vt frames video.mp4              # one frame every 15 s → sheet.jpg
vt frame video.mp4 --at 12:34.5  # the frame at that exact second
```

- `sheet.jpg` is a uniform grid: frame *k* (0-based) is at second
  `first_frame_at_s + k * interval_s`, which is in `manifest.json → sheet`. Use it to know where each
  tile sits in the video.
- **Extract individual frames only when the text points at something visual** ("here we see the
  diagram", "the code on the left", "this chart"): find the timestamp of that sentence in
  `transcript.md`, pull the frame at that second and look at it. One frame per question, not twenty.
- To capture a slide that stays on screen for several seconds, the midpoint of the block beats its
  start (it avoids the transition frame).

### 5. Answer with citations

Always cite the minute (`12:34`) when you claim something, so the user can verify it. If the claim is
visual, say which frame it came from.

## Limits you must state

- There's **text plus whatever frames you extract**: the model doesn't "see" the video or the motion.
- The diagram, data model or canvas **are yours to build** from that context: this skill doesn't draw
  them. If the video doesn't say something, don't fill it in.
- Loud music, several people at once or heavy accents with `tiny` → a poor transcript.
- If `vt transcribe` prints `0 segments`, the VAD found no speech (music/silence). Don't make it up:
  report it and offer to extract frames to describe what's on screen.
- If the user hands you a **URL** (YouTube, etc.), this skill doesn't download it yet: ask them to fetch
  the file or install `yt-dlp`. Don't download anything on your own.
- DRM-protected video: impossible. Say so.

## Environment details

- `vt` uses `uv` (PEP 723) and installs its dependencies in an isolated environment: **it never touches
  the system Python** and needs no setup. Only `ffmpeg` has to be on the machine.
- `vt` pins exact versions and runs with `--frozen` against `vt.lock`. **Don't add version ranges**: the
  Claude directory validation blocks launchers with unpinned versions. To change a dependency, edit the
  PEP 723 header and regenerate the lock with `uv lock --script vt`.
- Performance and quality per model: `reference.md` (read it only if the user asks about times, models
  or quality).
