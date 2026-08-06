import {
  clipAtTime,
  projectDuration,
  sourceTimeForClip,
  type Project,
  type TimelineClip,
} from "../types";
import { FILTER_CSS } from "./filters";

export type ExportProgress = {
  ratio: number;
  label: string;
};

/**
 * Renders the edited timeline to a downloadable WebM via canvas + MediaRecorder.
 */
export async function exportProject(
  project: Project,
  onProgress: (p: ExportProgress) => void,
  signal?: AbortSignal,
): Promise<Blob> {
  const duration = projectDuration(project.clips, project.texts);
  if (project.clips.length === 0) {
    throw new Error("Add at least one clip to export.");
  }

  // Determine output size from first media
  const firstMedia = project.media.find((m) => m.id === project.clips[0].mediaId);
  const outW = firstMedia?.width || 1280;
  const outH = firstMedia?.height || 720;

  const canvas = document.createElement("canvas");
  canvas.width = outW;
  canvas.height = outH;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas unsupported");

  // Preload video elements per media
  const videos = new Map<string, HTMLVideoElement>();
  for (const media of project.media) {
    const v = document.createElement("video");
    v.src = media.url;
    v.muted = false;
    v.playsInline = true;
    v.preload = "auto";
    await new Promise<void>((resolve, reject) => {
      v.onloadeddata = () => resolve();
      v.onerror = () => reject(new Error(`Failed to load ${media.name}`));
    });
    videos.set(media.id, v);
  }

  const stream = canvas.captureStream(30);
  // Mix audio from active clips via Web Audio when possible
  const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  let audioCtx: AudioContext | null = null;
  const dest = (() => {
    try {
      audioCtx = new AudioCtx();
      const destination = audioCtx.createMediaStreamDestination();
      destination.stream.getAudioTracks().forEach((t) => stream.addTrack(t));
      return destination;
    } catch {
      return null;
    }
  })();

  const sources = new Map<string, MediaElementAudioSourceNode>();
  if (audioCtx && dest) {
    for (const [id, v] of videos) {
      try {
        const src = audioCtx.createMediaElementSource(v);
        const gain = audioCtx.createGain();
        gain.gain.value = 1;
        src.connect(gain);
        gain.connect(dest);
        sources.set(id, src);
      } catch {
        // Already connected elsewhere — ignore
      }
    }
  }

  const mimeType = MediaRecorder.isTypeSupported("video/webm;codecs=vp9,opus")
    ? "video/webm;codecs=vp9,opus"
    : MediaRecorder.isTypeSupported("video/webm;codecs=vp8,opus")
      ? "video/webm;codecs=vp8,opus"
      : "video/webm";

  const chunks: BlobPart[] = [];
  const recorder = new MediaRecorder(stream, {
    mimeType,
    videoBitsPerSecond: 6_000_000,
  });

  recorder.ondataavailable = (e) => {
    if (e.data.size > 0) chunks.push(e.data);
  };

  const done = new Promise<Blob>((resolve, reject) => {
    recorder.onstop = () => resolve(new Blob(chunks, { type: mimeType }));
    recorder.onerror = () => reject(new Error("Recording failed"));
  });

  if (audioCtx?.state === "suspended") await audioCtx.resume();
  recorder.start(200);

  const fps = 30;
  const frameCount = Math.ceil(duration * fps);
  let lastClip: TimelineClip | null = null;

  onProgress({ ratio: 0, label: "Rendering…" });

  for (let i = 0; i < frameCount; i++) {
    if (signal?.aborted) {
      recorder.stop();
      videos.forEach((v) => {
        v.pause();
        v.removeAttribute("src");
      });
      audioCtx?.close();
      throw new DOMException("Export cancelled", "AbortError");
    }

    const t = i / fps;
    const clip = clipAtTime(project.clips, t);

    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, outW, outH);

    if (clip) {
      const media = project.media.find((m) => m.id === clip.mediaId);
      const video = videos.get(clip.mediaId);
      if (media && video) {
        const srcT = sourceTimeForClip(clip, t);
        if (Math.abs(video.currentTime - srcT) > 0.08) {
          await seekVideo(video, srcT);
        }
        if (lastClip?.id !== clip.id) {
          videos.forEach((v, id) => {
            if (id !== clip.mediaId) {
              v.pause();
              v.muted = true;
            }
          });
          video.muted = false;
          video.volume = clamp01(clip.volume);
          try {
            await video.play();
          } catch {
            /* autoplay may fail; frames still draw */
          }
          lastClip = clip;
        }

        ctx.filter = FILTER_CSS[clip.filter];
        drawContain(ctx, video, outW, outH);
        ctx.filter = "none";
      }
    } else {
      videos.forEach((v) => {
        v.pause();
        v.muted = true;
      });
      lastClip = null;
    }

    // Text overlays
    for (const text of project.texts) {
      if (t >= text.start && t < text.end) {
        ctx.save();
        ctx.font = `700 ${Math.round(text.fontSize * (outW / 720))}px Syne, Figtree, sans-serif`;
        ctx.fillStyle = text.color;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.shadowColor = "rgba(0,0,0,0.55)";
        ctx.shadowBlur = 12;
        ctx.fillText(text.text, text.x * outW, text.y * outH, outW * 0.9);
        ctx.restore();
      }
    }

    onProgress({
      ratio: (i + 1) / frameCount,
      label: `Rendering ${Math.round(((i + 1) / frameCount) * 100)}%`,
    });

    // Pace roughly real-time for MediaRecorder / audio sync
    await wait(1000 / fps);
  }

  videos.forEach((v) => {
    v.pause();
  });
  recorder.stop();
  const blob = await done;

  videos.forEach((v) => {
    v.removeAttribute("src");
    v.load();
  });
  await audioCtx?.close();

  onProgress({ ratio: 1, label: "Done" });
  return blob;
}

function clamp01(n: number) {
  return Math.min(1, Math.max(0, n));
}

function drawContain(
  ctx: CanvasRenderingContext2D,
  video: HTMLVideoElement,
  outW: number,
  outH: number,
) {
  const vw = video.videoWidth || outW;
  const vh = video.videoHeight || outH;
  const scale = Math.min(outW / vw, outH / vh);
  const w = vw * scale;
  const h = vh * scale;
  const x = (outW - w) / 2;
  const y = (outH - h) / 2;
  ctx.drawImage(video, x, y, w, h);
}

function seekVideo(video: HTMLVideoElement, time: number): Promise<void> {
  return new Promise((resolve) => {
    const onSeeked = () => {
      video.removeEventListener("seeked", onSeeked);
      resolve();
    };
    video.addEventListener("seeked", onSeeked);
    video.currentTime = time;
  });
}

function wait(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

export function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
