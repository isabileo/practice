# CUT

**Effortless video editing in your browser.**

Import clips, trim and split on a timeline, add titles and looks, then export — no install, no account.

## Features

- **Drag-and-drop import** — MP4, WebM, MOV, and other browser-supported formats
- **Timeline editing** — move, trim (in/out handles), split at playhead (`S`)
- **Titles** — overlay text with size, color, and timing
- **Looks** — Warm, Cool, Mono, Vivid, Fade
- **Speed & volume** per clip
- **Export** — download a WebM of your edit
- **Keyboard** — `Space` play/pause · `S` split · `←`/`→` nudge · `Delete` remove

## Run locally

```bash
cd video-editor
npm install
npm run dev
```

Open the URL Vite prints (usually `http://localhost:5173`).

## Build

```bash
cd video-editor
npm run build
npm run preview
```

## Tips

1. Drop one or more videos on the welcome screen — they’re placed end-to-end on the timeline.
2. Click a clip to trim in the inspector, or drag the edge handles on the timeline.
3. Press **Title** to add on-screen text at the playhead.
4. Hit **Export** when you’re ready; rendering runs in the browser (realtime-ish).

> Export uses the Canvas + MediaRecorder APIs and saves **WebM**. For other containers, convert with ffmpeg after download.
