import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { v4 as uuid } from "uuid";
import {
  clipAtTime,
  clipDuration,
  projectDuration,
  sourceTimeForClip,
  type FilterPreset,
  type MediaItem,
  type Project,
  type TextOverlay,
  type TimelineClip,
} from "./types";
import { loadMediaFromFile } from "./lib/media";
import { downloadBlob, exportProject } from "./lib/export";
import { FILTER_CSS, FILTER_LABELS } from "./lib/filters";
import { clamp, formatTime } from "./lib/time";
import {
  AUTO_EDIT_PRESETS,
  analyzeProjectForAutoEdit,
  applyAutoEdit,
  type AutoEditPreset,
  type AutoEditPreview,
} from "./lib/autoEdit";
import "./App.css";

type Selection =
  | { kind: "clip"; id: string }
  | { kind: "text"; id: string }
  | null;

const EMPTY: Project = { media: [], clips: [], texts: [] };

export default function App() {
  const [project, setProject] = useState<Project>(EMPTY);
  const [selection, setSelection] = useState<Selection>(null);
  const [currentTime, setCurrentTime] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [pxPerSec, setPxPerSec] = useState(64);
  const [importing, setImporting] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [exportRatio, setExportRatio] = useState(0);
  const [exportLabel, setExportLabel] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [autoOpen, setAutoOpen] = useState(false);
  const [autoPreset, setAutoPreset] = useState<AutoEditPreset>("balanced");
  const [autoAnalyzing, setAutoAnalyzing] = useState(false);
  const [autoLabel, setAutoLabel] = useState("");
  const [autoRatio, setAutoRatio] = useState(0);
  const [autoPreview, setAutoPreview] = useState<AutoEditPreview | null>(null);
  const [undoClips, setUndoClips] = useState<TimelineClip[] | null>(null);

  const videoRef = useRef<HTMLVideoElement>(null);
  const rafRef = useRef<number>(0);
  const playStartRef = useRef({ wall: 0, time: 0 });
  const abortRef = useRef<AbortController | null>(null);
  const autoAbortRef = useRef<AbortController | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const duration = useMemo(
    () => projectDuration(project.clips, project.texts),
    [project.clips, project.texts],
  );

  const activeClip = useMemo(
    () => clipAtTime(project.clips, currentTime),
    [project.clips, currentTime],
  );

  const activeMedia = useMemo(() => {
    if (!activeClip) return null;
    return project.media.find((m) => m.id === activeClip.mediaId) ?? null;
  }, [activeClip, project.media]);

  const selectedClip = useMemo(() => {
    if (selection?.kind !== "clip") return null;
    return project.clips.find((c) => c.id === selection.id) ?? null;
  }, [selection, project.clips]);

  const selectedText = useMemo(() => {
    if (selection?.kind !== "text") return null;
    return project.texts.find((t) => t.id === selection.id) ?? null;
  }, [selection, project.texts]);

  const activeTexts = useMemo(
    () =>
      project.texts.filter((t) => currentTime >= t.start && currentTime < t.end),
    [project.texts, currentTime],
  );

  const hasContent = project.media.length > 0 || project.clips.length > 0;

  const importFiles = useCallback(async (files: FileList | File[]) => {
    const list = Array.from(files).filter((f) => f.type.startsWith("video/"));
    if (list.length === 0) {
      setError("Drop video files (MP4, WebM, MOV…).");
      return;
    }
    setImporting(true);
    setError(null);
    try {
      const loaded: MediaItem[] = [];
      for (const file of list) {
        const meta = await loadMediaFromFile(file);
        loaded.push({
          id: uuid(),
          name: file.name,
          ...meta,
        });
      }
      setProject((prev) => {
        let nextOffset = projectDuration(prev.clips, prev.texts);
        if (prev.clips.length === 0) nextOffset = 0;
        const newClips: TimelineClip[] = loaded.map((m) => {
          const clip: TimelineClip = {
            id: uuid(),
            mediaId: m.id,
            inPoint: 0,
            outPoint: m.duration,
            offset: nextOffset,
            volume: 1,
            speed: 1,
            filter: "none",
          };
          nextOffset += clipDuration(clip);
          return clip;
        });
        return {
          media: [...prev.media, ...loaded],
          clips: [...prev.clips, ...newClips],
          texts: prev.texts,
        };
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Import failed");
    } finally {
      setImporting(false);
    }
  }, []);

  // Sync video element to timeline
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (!activeClip || !activeMedia) {
      video.pause();
      video.removeAttribute("src");
      return;
    }
    if (video.src !== activeMedia.url) {
      video.src = activeMedia.url;
    }
    video.volume = clamp(activeClip.volume, 0, 1);
    video.playbackRate = activeClip.speed;
    const srcT = sourceTimeForClip(activeClip, currentTime);
    if (Math.abs(video.currentTime - srcT) > 0.12) {
      video.currentTime = srcT;
    }
  }, [activeClip, activeMedia, currentTime]);

  // Playback loop
  useEffect(() => {
    if (!playing) {
      cancelAnimationFrame(rafRef.current);
      videoRef.current?.pause();
      return;
    }

    playStartRef.current = { wall: performance.now(), time: currentTime };
    const video = videoRef.current;
    if (video && activeClip) {
      video.play().catch(() => undefined);
    }

    const tick = (now: number) => {
      const elapsed = (now - playStartRef.current.wall) / 1000;
      let next = playStartRef.current.time + elapsed;
      if (next >= duration) {
        next = duration;
        setCurrentTime(next);
        setPlaying(false);
        return;
      }
      setCurrentTime(next);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playing, duration]);

  // Keyboard shortcuts
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;

      if (e.code === "Space") {
        e.preventDefault();
        setPlaying((p) => !p);
      } else if (e.key === "s" || e.key === "S") {
        e.preventDefault();
        splitAtPlayhead();
      } else if (e.key === "Delete" || e.key === "Backspace") {
        if (selection?.kind === "clip") deleteClip(selection.id);
        if (selection?.kind === "text") deleteText(selection.id);
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        setPlaying(false);
        setCurrentTime((t) => clamp(t - (e.shiftKey ? 1 : 0.1), 0, duration));
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        setPlaying(false);
        setCurrentTime((t) => clamp(t + (e.shiftKey ? 1 : 0.1), 0, duration));
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selection, duration, project.clips, currentTime]);

  function updateClip(id: string, patch: Partial<TimelineClip>) {
    setProject((prev) => ({
      ...prev,
      clips: prev.clips.map((c) => (c.id === id ? { ...c, ...patch } : c)),
    }));
  }

  function updateText(id: string, patch: Partial<TextOverlay>) {
    setProject((prev) => ({
      ...prev,
      texts: prev.texts.map((t) => (t.id === id ? { ...t, ...patch } : t)),
    }));
  }

  function deleteClip(id: string) {
    setProject((prev) => ({
      ...prev,
      clips: prev.clips.filter((c) => c.id !== id),
    }));
    if (selection?.kind === "clip" && selection.id === id) setSelection(null);
  }

  function deleteText(id: string) {
    setProject((prev) => ({
      ...prev,
      texts: prev.texts.filter((t) => t.id !== id),
    }));
    if (selection?.kind === "text" && selection.id === id) setSelection(null);
  }

  function splitAtPlayhead() {
    const clip = clipAtTime(project.clips, currentTime);
    if (!clip) return;
    const local = currentTime - clip.offset;
    if (local <= 0.05 || local >= clipDuration(clip) - 0.05) return;
    const splitSource = clip.inPoint + local * clip.speed;
    const rightId = uuid();
    const left: TimelineClip = {
      ...clip,
      outPoint: splitSource,
    };
    const right: TimelineClip = {
      ...clip,
      id: rightId,
      inPoint: splitSource,
      offset: currentTime,
    };
    setProject((prev) => ({
      ...prev,
      clips: prev.clips.flatMap((c) => (c.id === clip.id ? [left, right] : [c])),
    }));
    setSelection({ kind: "clip", id: rightId });
    // Nudge zoom if the cut is hard to see
    setPxPerSec((z) => Math.max(z, 80));
  }

  function addText() {
    const id = uuid();
    const start = currentTime;
    const end = Math.min(duration || start + 3, start + 3);
    const text: TextOverlay = {
      id,
      text: "Your title",
      start,
      end: Math.max(end, start + 1),
      x: 0.5,
      y: 0.82,
      fontSize: 42,
      color: "#f4f7f6",
    };
    setProject((prev) => ({ ...prev, texts: [...prev.texts, text] }));
    setSelection({ kind: "text", id });
  }

  function rippleCloseGaps() {
    setProject((prev) => {
      const sorted = [...prev.clips].sort((a, b) => a.offset - b.offset);
      let cursor = 0;
      const clips = sorted.map((c) => {
        const next = { ...c, offset: cursor };
        cursor += clipDuration(next);
        return next;
      });
      return { ...prev, clips };
    });
  }

  async function handleExport() {
    if (project.clips.length === 0) {
      setError("Add clips before exporting.");
      return;
    }
    setExporting(true);
    setExportRatio(0);
    setExportLabel("Preparing…");
    setPlaying(false);
    const abort = new AbortController();
    abortRef.current = abort;
    try {
      const blob = await exportProject(
        project,
        (p) => {
          setExportRatio(p.ratio);
          setExportLabel(p.label);
        },
        abort.signal,
      );
      downloadBlob(blob, `cut-export-${Date.now()}.webm`);
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") {
        setExportLabel("Cancelled");
      } else {
        setError(e instanceof Error ? e.message : "Export failed");
      }
    } finally {
      setExporting(false);
      abortRef.current = null;
    }
  }

  function openAutoEdit() {
    setAutoOpen(true);
    setAutoPreview(null);
    setAutoLabel("");
    setAutoRatio(0);
    setPlaying(false);
  }

  async function runAutoAnalyze(preset: AutoEditPreset = autoPreset) {
    if (project.clips.length === 0) {
      setError("Add clips before Auto Edit.");
      return;
    }
    setAutoAnalyzing(true);
    setAutoPreview(null);
    setAutoLabel("Starting…");
    setAutoRatio(0);
    const abort = new AbortController();
    autoAbortRef.current = abort;
    try {
      const preview = await analyzeProjectForAutoEdit(
        project,
        AUTO_EDIT_PRESETS[preset].options,
        (label, ratio) => {
          setAutoLabel(label);
          setAutoRatio(ratio);
        },
        abort.signal,
      );
      setAutoPreview(preview);
      setAutoLabel(
        preview.silenceRemoved < 0.05
          ? "Looks clean — little silence to cut"
          : `Ready to remove ${formatTime(preview.silenceRemoved)} of dead air`,
      );
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") {
        setAutoLabel("Cancelled");
      } else {
        setError(e instanceof Error ? e.message : "Auto Edit analysis failed");
        setAutoOpen(false);
      }
    } finally {
      setAutoAnalyzing(false);
      autoAbortRef.current = null;
    }
  }

  function applyAutoEditResult() {
    if (!autoPreview) return;
    setUndoClips(project.clips);
    const nextClips = applyAutoEdit(project, autoPreview);
    if (nextClips.length === 0) {
      setError("Auto Edit would remove everything — try Gentle.");
      return;
    }
    setProject((prev) => ({ ...prev, clips: nextClips }));
    setSelection(null);
    setCurrentTime(0);
    setPlaying(false);
    setAutoOpen(false);
    setAutoPreview(null);
  }

  function undoAutoEdit() {
    if (!undoClips) return;
    setProject((prev) => ({ ...prev, clips: undoClips }));
    setUndoClips(null);
    setCurrentTime(0);
  }

  function seekFromPreview(clientX: number, el: HTMLElement) {
    const rect = el.getBoundingClientRect();
    const ratio = clamp((clientX - rect.left) / rect.width, 0, 1);
    setPlaying(false);
    setCurrentTime(ratio * duration);
  }

  // ——— Welcome / empty state ———
  if (!hasContent) {
    return (
      <div className="shell welcome-shell">
        <div className="welcome-atmosphere" aria-hidden />
        <header className="welcome-brand">
          <div className="logo-mark" aria-hidden>
            <span className="logo-blade" />
            <span className="logo-bar" />
          </div>
          <h1 className="brand-name">CUT</h1>
          <p className="brand-tag">Edit video effortlessly</p>
        </header>

        <label
          className={`dropzone ${dragOver ? "is-over" : ""} ${importing ? "is-busy" : ""}`}
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDragOver(false);
            void importFiles(e.dataTransfer.files);
          }}
        >
          <input
            type="file"
            accept="video/*"
            multiple
            hidden
            onChange={(e) => {
              if (e.target.files) void importFiles(e.target.files);
            }}
          />
          <div className="dropzone-inner">
            <span className="dropzone-pulse" aria-hidden />
            <p className="dropzone-title">
              {importing ? "Importing…" : "Drop videos here"}
            </p>
            <p className="dropzone-sub">or click to browse — MP4, WebM, MOV</p>
          </div>
        </label>

        {error && <p className="toast-error">{error}</p>}

        <ul className="welcome-hints">
          <li>Auto Edit removes pauses &amp; dead air</li>
          <li>Trim &amp; split on the timeline</li>
          <li>Export when you’re done</li>
        </ul>
      </div>
    );
  }

  // ——— Editor ———
  return (
    <div className="shell editor-shell">
      <header className="topbar">
        <div className="topbar-brand">
          <div className="logo-mark sm" aria-hidden>
            <span className="logo-blade" />
            <span className="logo-bar" />
          </div>
          <span className="brand-name sm">CUT</span>
        </div>

        <div className="topbar-actions">
          <button
            type="button"
            className="btn ghost"
            onClick={() => fileInputRef.current?.click()}
            disabled={importing}
          >
            {importing ? "Importing…" : "Import"}
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept="video/*"
            multiple
            hidden
            onChange={(e) => {
              if (e.target.files) void importFiles(e.target.files);
            }}
          />
          <button
            type="button"
            className="btn accent"
            onClick={openAutoEdit}
            disabled={project.clips.length === 0}
            title="Cut silence and long pauses automatically"
          >
            Auto Edit
          </button>
          {undoClips && (
            <button type="button" className="btn ghost" onClick={undoAutoEdit}>
              Undo Auto
            </button>
          )}
          <button type="button" className="btn ghost" onClick={addText}>
            Title
          </button>
          <button type="button" className="btn ghost" onClick={splitAtPlayhead}>
            Split
          </button>
          <button type="button" className="btn ghost" onClick={rippleCloseGaps}>
            Close gaps
          </button>
          <button
            type="button"
            className="btn primary"
            onClick={() => void handleExport()}
            disabled={exporting || project.clips.length === 0}
          >
            {exporting ? "Exporting…" : "Export"}
          </button>
        </div>
      </header>

      <div className="workspace">
        <aside className="media-rail">
          <h2 className="rail-label">Media</h2>
          <div className="media-grid">
            {project.media.map((m) => (
              <button
                key={m.id}
                type="button"
                className="media-card"
                title={`Add ${m.name} again`}
                onClick={() => {
                  setProject((prev) => {
                    const offset = projectDuration(prev.clips, prev.texts);
                    const clip: TimelineClip = {
                      id: uuid(),
                      mediaId: m.id,
                      inPoint: 0,
                      outPoint: m.duration,
                      offset,
                      volume: 1,
                      speed: 1,
                      filter: "none",
                    };
                    return { ...prev, clips: [...prev.clips, clip] };
                  });
                }}
              >
                <img src={m.thumbnail} alt="" />
                <span>{m.name}</span>
              </button>
            ))}
          </div>
          <label
            className="rail-drop"
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              void importFiles(e.dataTransfer.files);
            }}
          >
            <input
              type="file"
              accept="video/*"
              multiple
              hidden
              onChange={(e) => {
                if (e.target.files) void importFiles(e.target.files);
              }}
            />
            + Add media
          </label>
        </aside>

        <main className="preview-stage">
          <div
            className="preview-frame"
            onClick={(e) => {
              if ((e.target as HTMLElement).closest(".preview-controls")) return;
            }}
          >
            <div className="preview-screen">
              {activeMedia ? (
                <video
                  ref={videoRef}
                  className="preview-video"
                  style={{ filter: FILTER_CSS[activeClip?.filter ?? "none"] }}
                  playsInline
                  muted={false}
                />
              ) : (
                <div className="preview-empty">
                  {activeTexts.length > 0
                    ? null
                    : "Move the playhead onto a clip"}
                </div>
              )}
              {activeTexts.map((t) => (
                <div
                  key={t.id}
                  className="preview-text"
                  style={{
                    left: `${t.x * 100}%`,
                    top: `${t.y * 100}%`,
                    fontSize: `clamp(14px, ${t.fontSize * 0.08}vw, ${t.fontSize}px)`,
                    color: t.color,
                  }}
                >
                  {t.text}
                </div>
              ))}
            </div>
          </div>

          <div className="preview-controls">
            <button
              type="button"
              className="btn icon"
              aria-label={playing ? "Pause" : "Play"}
              onClick={() => setPlaying((p) => !p)}
            >
              {playing ? (
                <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden>
                  <rect x="6" y="5" width="4" height="14" fill="currentColor" />
                  <rect x="14" y="5" width="4" height="14" fill="currentColor" />
                </svg>
              ) : (
                <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden>
                  <path d="M8 5v14l11-7z" fill="currentColor" />
                </svg>
              )}
            </button>
            <div
              className="scrubber"
              role="slider"
              aria-valuemin={0}
              aria-valuemax={duration}
              aria-valuenow={currentTime}
              tabIndex={0}
              onPointerDown={(e) => {
                const el = e.currentTarget;
                seekFromPreview(e.clientX, el);
                const move = (ev: PointerEvent) => seekFromPreview(ev.clientX, el);
                const up = () => {
                  window.removeEventListener("pointermove", move);
                  window.removeEventListener("pointerup", up);
                };
                window.addEventListener("pointermove", move);
                window.addEventListener("pointerup", up);
              }}
            >
              <div
                className="scrubber-fill"
                style={{ width: `${(currentTime / duration) * 100}%` }}
              />
            </div>
            <span className="time-readout">
              {formatTime(currentTime, true)} / {formatTime(duration, true)}
            </span>
          </div>
        </main>

        <aside className="inspector">
          <h2 className="rail-label">Inspector</h2>
          {!selectedClip && !selectedText && (
            <p className="inspector-empty">
              Select a clip or title on the timeline.
              <br />
              <span className="kbd-hint">Space play · S split · ⌫ delete</span>
            </p>
          )}

          {selectedClip && (
            <div className="inspector-form">
              <h3>Clip</h3>
              <label>
                In
                <input
                  type="number"
                  min={0}
                  step={0.05}
                  max={selectedClip.outPoint - 0.05}
                  value={Number(selectedClip.inPoint.toFixed(2))}
                  onChange={(e) =>
                    updateClip(selectedClip.id, {
                      inPoint: clamp(
                        Number(e.target.value),
                        0,
                        selectedClip.outPoint - 0.05,
                      ),
                    })
                  }
                />
              </label>
              <label>
                Out
                <input
                  type="number"
                  min={selectedClip.inPoint + 0.05}
                  step={0.05}
                  value={Number(selectedClip.outPoint.toFixed(2))}
                  onChange={(e) => {
                    const media = project.media.find(
                      (m) => m.id === selectedClip.mediaId,
                    );
                    updateClip(selectedClip.id, {
                      outPoint: clamp(
                        Number(e.target.value),
                        selectedClip.inPoint + 0.05,
                        media?.duration ?? selectedClip.outPoint,
                      ),
                    });
                  }}
                />
              </label>
              <label>
                Volume
                <input
                  type="range"
                  min={0}
                  max={1}
                  step={0.01}
                  value={selectedClip.volume}
                  onChange={(e) =>
                    updateClip(selectedClip.id, {
                      volume: Number(e.target.value),
                    })
                  }
                />
              </label>
              <label>
                Speed
                <select
                  value={selectedClip.speed}
                  onChange={(e) =>
                    updateClip(selectedClip.id, {
                      speed: Number(e.target.value),
                    })
                  }
                >
                  {[0.5, 0.75, 1, 1.25, 1.5, 2].map((s) => (
                    <option key={s} value={s}>
                      {s}×
                    </option>
                  ))}
                </select>
              </label>
              <fieldset>
                <legend>Look</legend>
                <div className="filter-row">
                  {(Object.keys(FILTER_LABELS) as FilterPreset[]).map((f) => (
                    <button
                      key={f}
                      type="button"
                      className={`chip ${selectedClip.filter === f ? "active" : ""}`}
                      onClick={() => updateClip(selectedClip.id, { filter: f })}
                    >
                      {FILTER_LABELS[f]}
                    </button>
                  ))}
                </div>
              </fieldset>
              <button
                type="button"
                className="btn danger"
                onClick={() => deleteClip(selectedClip.id)}
              >
                Delete clip
              </button>
            </div>
          )}

          {selectedText && (
            <div className="inspector-form">
              <h3>Title</h3>
              <label>
                Text
                <input
                  type="text"
                  value={selectedText.text}
                  onChange={(e) =>
                    updateText(selectedText.id, { text: e.target.value })
                  }
                />
              </label>
              <label>
                Start
                <input
                  type="number"
                  min={0}
                  step={0.1}
                  value={Number(selectedText.start.toFixed(2))}
                  onChange={(e) =>
                    updateText(selectedText.id, {
                      start: Math.max(0, Number(e.target.value)),
                    })
                  }
                />
              </label>
              <label>
                End
                <input
                  type="number"
                  min={0}
                  step={0.1}
                  value={Number(selectedText.end.toFixed(2))}
                  onChange={(e) =>
                    updateText(selectedText.id, {
                      end: Math.max(
                        selectedText.start + 0.2,
                        Number(e.target.value),
                      ),
                    })
                  }
                />
              </label>
              <label>
                Size
                <input
                  type="range"
                  min={18}
                  max={96}
                  value={selectedText.fontSize}
                  onChange={(e) =>
                    updateText(selectedText.id, {
                      fontSize: Number(e.target.value),
                    })
                  }
                />
              </label>
              <label>
                Color
                <input
                  type="color"
                  value={selectedText.color}
                  onChange={(e) =>
                    updateText(selectedText.id, { color: e.target.value })
                  }
                />
              </label>
              <label>
                Vertical
                <input
                  type="range"
                  min={0.1}
                  max={0.9}
                  step={0.01}
                  value={selectedText.y}
                  onChange={(e) =>
                    updateText(selectedText.id, { y: Number(e.target.value) })
                  }
                />
              </label>
              <button
                type="button"
                className="btn danger"
                onClick={() => deleteText(selectedText.id)}
              >
                Delete title
              </button>
            </div>
          )}
        </aside>
      </div>

      <Timeline
        project={project}
        currentTime={currentTime}
        duration={duration}
        pxPerSec={pxPerSec}
        selection={selection}
        onSelect={setSelection}
        onSeek={(t) => {
          setPlaying(false);
          setCurrentTime(clamp(t, 0, duration));
        }}
        onTrim={(id, edge, sourceTime) => {
          const clip = project.clips.find((c) => c.id === id);
          if (!clip) return;
          const media = project.media.find((m) => m.id === clip.mediaId);
          if (!media) return;
          if (edge === "in") {
            const inPoint = clamp(sourceTime, 0, clip.outPoint - 0.05);
            const delta = (inPoint - clip.inPoint) / clip.speed;
            updateClip(id, {
              inPoint,
              offset: clip.offset + delta,
            });
          } else {
            updateClip(id, {
              outPoint: clamp(sourceTime, clip.inPoint + 0.05, media.duration),
            });
          }
        }}
        onMoveClip={(id, newOffset) => {
          updateClip(id, { offset: Math.max(0, newOffset) });
        }}
        onZoom={setPxPerSec}
      />

      {error && (
        <div className="toast-error floating" role="alert">
          {error}
          <button type="button" onClick={() => setError(null)}>
            ×
          </button>
        </div>
      )}

      {exporting && (
        <div className="export-overlay" role="dialog" aria-modal>
          <div className="export-panel">
            <h2>Exporting</h2>
            <p>{exportLabel}</p>
            <div className="export-bar">
              <div style={{ width: `${exportRatio * 100}%` }} />
            </div>
            <button
              type="button"
              className="btn ghost"
              onClick={() => abortRef.current?.abort()}
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {autoOpen && (
        <div className="export-overlay" role="dialog" aria-modal aria-labelledby="auto-edit-title">
          <div className="export-panel auto-panel">
            <h2 id="auto-edit-title">Auto Edit</h2>
            <p className="auto-lead">
              CUT listens for dead air and long pauses, then cuts those mistakes
              before you fine-tune by hand.
            </p>

            <div className="preset-row" role="radiogroup" aria-label="Auto Edit strength">
              {(Object.keys(AUTO_EDIT_PRESETS) as AutoEditPreset[]).map((key) => {
                const preset = AUTO_EDIT_PRESETS[key];
                return (
                  <button
                    key={key}
                    type="button"
                    role="radio"
                    aria-checked={autoPreset === key}
                    className={`preset-card ${autoPreset === key ? "active" : ""}`}
                    disabled={autoAnalyzing}
                    onClick={() => {
                      setAutoPreset(key);
                      setAutoPreview(null);
                    }}
                  >
                    <strong>{preset.label}</strong>
                    <span>{preset.hint}</span>
                  </button>
                );
              })}
            </div>

            {(autoAnalyzing || autoLabel) && (
              <div className="auto-status">
                <p>{autoLabel || "Working…"}</p>
                {autoAnalyzing && (
                  <div className="export-bar">
                    <div style={{ width: `${Math.max(autoRatio, 0.08) * 100}%` }} />
                  </div>
                )}
              </div>
            )}

            {autoPreview && !autoAnalyzing && (
              <dl className="auto-stats">
                <div>
                  <dt>Before</dt>
                  <dd>{formatTime(autoPreview.originalDuration, true)}</dd>
                </div>
                <div>
                  <dt>After</dt>
                  <dd>{formatTime(autoPreview.newDuration, true)}</dd>
                </div>
                <div>
                  <dt>Removed</dt>
                  <dd>{formatTime(autoPreview.silenceRemoved, true)}</dd>
                </div>
                <div>
                  <dt>Cuts</dt>
                  <dd>{autoPreview.cutsRemoved}</dd>
                </div>
              </dl>
            )}

            <div className="auto-actions">
              <button
                type="button"
                className="btn ghost"
                onClick={() => {
                  autoAbortRef.current?.abort();
                  setAutoOpen(false);
                  setAutoPreview(null);
                }}
              >
                Close
              </button>
              <button
                type="button"
                className="btn ghost"
                disabled={autoAnalyzing}
                onClick={() => void runAutoAnalyze()}
              >
                {autoAnalyzing ? "Analyzing…" : autoPreview ? "Re-analyze" : "Analyze"}
              </button>
              <button
                type="button"
                className="btn primary"
                disabled={autoAnalyzing || !autoPreview || autoPreview.silenceRemoved < 0.05}
                onClick={applyAutoEditResult}
              >
                Apply cuts
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

type TimelineProps = {
  project: Project;
  currentTime: number;
  duration: number;
  pxPerSec: number;
  selection: Selection;
  onSelect: (s: Selection) => void;
  onSeek: (t: number) => void;
  onTrim: (id: string, edge: "in" | "out", sourceTime: number) => void;
  onMoveClip: (id: string, offset: number) => void;
  onZoom: (px: number) => void;
};

function Timeline({
  project,
  currentTime,
  duration,
  pxPerSec,
  selection,
  onSelect,
  onSeek,
  onTrim,
  onMoveClip,
  onZoom,
}: TimelineProps) {
  const trackRef = useRef<HTMLDivElement>(null);
  const width = Math.max(duration * pxPerSec + 120, 600);

  function timeFromClientX(clientX: number): number {
    const el = trackRef.current;
    if (!el) return 0;
    const rect = el.getBoundingClientRect();
    const x = clientX - rect.left + el.scrollLeft;
    return clamp(x / pxPerSec, 0, duration);
  }

  return (
    <section className="timeline">
      <div className="timeline-toolbar">
        <span className="rail-label">Timeline</span>
        <div className="zoom-controls">
          <button
            type="button"
            className="btn icon sm"
            aria-label="Zoom out"
            onClick={() => onZoom(clamp(pxPerSec / 1.25, 24, 200))}
          >
            −
          </button>
          <button
            type="button"
            className="btn icon sm"
            aria-label="Zoom in"
            onClick={() => onZoom(clamp(pxPerSec * 1.25, 24, 200))}
          >
            +
          </button>
        </div>
      </div>

      <div
        className="timeline-scroll"
        ref={trackRef}
        onClick={(e) => {
          if ((e.target as HTMLElement).closest(".tl-clip, .tl-text")) return;
          onSeek(timeFromClientX(e.clientX));
          onSelect(null);
        }}
      >
        <div className="timeline-inner" style={{ width }}>
          <div className="ruler">
            {Array.from({ length: Math.ceil(duration) + 1 }, (_, i) => (
              <span
                key={i}
                className="ruler-tick"
                style={{ left: i * pxPerSec }}
              >
                {formatTime(i)}
              </span>
            ))}
          </div>

          <div className="track video-track">
            {project.clips.map((clip) => {
              const media = project.media.find((m) => m.id === clip.mediaId);
              const dur = clipDuration(clip);
              const selected =
                selection?.kind === "clip" && selection.id === clip.id;
              return (
                <div
                  key={clip.id}
                  className={`tl-clip ${selected ? "selected" : ""}`}
                  style={{
                    left: clip.offset * pxPerSec,
                    width: Math.max(dur * pxPerSec, 8),
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    onSelect({ kind: "clip", id: clip.id });
                  }}
                  onPointerDown={(e) => {
                    if ((e.target as HTMLElement).dataset.handle) return;
                    e.stopPropagation();
                    onSelect({ kind: "clip", id: clip.id });
                    const startX = e.clientX;
                    const startOffset = clip.offset;
                    const move = (ev: PointerEvent) => {
                      const dx = ev.clientX - startX;
                      onMoveClip(clip.id, startOffset + dx / pxPerSec);
                    };
                    const up = () => {
                      window.removeEventListener("pointermove", move);
                      window.removeEventListener("pointerup", up);
                    };
                    window.addEventListener("pointermove", move);
                    window.addEventListener("pointerup", up);
                  }}
                >
                  <span
                    className="tl-handle in"
                    data-handle="in"
                    onPointerDown={(e) => {
                      e.stopPropagation();
                      const move = (ev: PointerEvent) => {
                        const t = timeFromClientX(ev.clientX);
                        const local = t - clip.offset;
                        const source = clip.inPoint + local * clip.speed;
                        onTrim(clip.id, "in", source);
                      };
                      const up = () => {
                        window.removeEventListener("pointermove", move);
                        window.removeEventListener("pointerup", up);
                      };
                      window.addEventListener("pointermove", move);
                      window.addEventListener("pointerup", up);
                    }}
                  />
                  <div className="tl-clip-body">
                    {media?.thumbnail && (
                      <img src={media.thumbnail} alt="" draggable={false} />
                    )}
                    <span>{media?.name ?? "Clip"}</span>
                  </div>
                  <span
                    className="tl-handle out"
                    data-handle="out"
                    onPointerDown={(e) => {
                      e.stopPropagation();
                      const move = (ev: PointerEvent) => {
                        const t = timeFromClientX(ev.clientX);
                        const local = t - clip.offset;
                        const source = clip.inPoint + local * clip.speed;
                        onTrim(clip.id, "out", source);
                      };
                      const up = () => {
                        window.removeEventListener("pointermove", move);
                        window.removeEventListener("pointerup", up);
                      };
                      window.addEventListener("pointermove", move);
                      window.addEventListener("pointerup", up);
                    }}
                  />
                </div>
              );
            })}
          </div>

          <div className="track text-track">
            {project.texts.map((text) => {
              const selected =
                selection?.kind === "text" && selection.id === text.id;
              return (
                <div
                  key={text.id}
                  className={`tl-text ${selected ? "selected" : ""}`}
                  style={{
                    left: text.start * pxPerSec,
                    width: Math.max((text.end - text.start) * pxPerSec, 8),
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    onSelect({ kind: "text", id: text.id });
                  }}
                >
                  {text.text}
                </div>
              );
            })}
          </div>

          <div
            className="playhead"
            style={{ left: currentTime * pxPerSec }}
            onPointerDown={(e) => {
              e.stopPropagation();
              const move = (ev: PointerEvent) => onSeek(timeFromClientX(ev.clientX));
              const up = () => {
                window.removeEventListener("pointermove", move);
                window.removeEventListener("pointerup", up);
              };
              window.addEventListener("pointermove", move);
              window.addEventListener("pointerup", up);
            }}
          >
            <span className="playhead-head" />
          </div>
        </div>
      </div>
    </section>
  );
}
