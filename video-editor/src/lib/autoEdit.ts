import { v4 as uuid } from "uuid";
import {
  clipDuration,
  type MediaItem,
  type Project,
  type TimelineClip,
} from "../types";

export type AutoEditPreset = "gentle" | "balanced" | "aggressive";

export type AutoEditOptions = {
  /** RMS threshold relative to peak (0–1). Lower = more aggressive cuts. */
  silenceThreshold: number;
  /** Only remove silent gaps longer than this (seconds). */
  minSilence: number;
  /** Keep this much audio around speech edges (seconds). */
  padding: number;
  /** Drop leading/trailing silence even if short. */
  trimEnds: boolean;
};

export const AUTO_EDIT_PRESETS: Record<
  AutoEditPreset,
  { label: string; hint: string; options: AutoEditOptions }
> = {
  gentle: {
    label: "Gentle",
    hint: "Trim dead air at the ends; keep natural pauses",
    options: {
      silenceThreshold: 0.045,
      minSilence: 0.85,
      padding: 0.18,
      trimEnds: true,
    },
  },
  balanced: {
    label: "Balanced",
    hint: "Cut long pauses and hesitations — best default",
    options: {
      silenceThreshold: 0.055,
      minSilence: 0.45,
      padding: 0.12,
      trimEnds: true,
    },
  },
  aggressive: {
    label: "Aggressive",
    hint: "Jump-cut style — remove most quiet mistakes",
    options: {
      silenceThreshold: 0.07,
      minSilence: 0.28,
      padding: 0.08,
      trimEnds: true,
    },
  },
};

export type TimeRange = { start: number; end: number };

export type AutoEditPreview = {
  originalDuration: number;
  newDuration: number;
  cutsRemoved: number;
  silenceRemoved: number;
  keepersByClip: Map<string, TimeRange[]>;
};

const WINDOW_SEC = 0.05;

/**
 * Decode media audio into a mono Float32Array of samples + sampleRate.
 * Returns null when the file has no usable audio track.
 */
export async function decodeMediaAudio(
  url: string,
  signal?: AbortSignal,
): Promise<{ samples: Float32Array; sampleRate: number } | null> {
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error("Could not read media for analysis");
  const buffer = await res.arrayBuffer();

  const AudioCtx =
    window.AudioContext ||
    (window as unknown as { webkitAudioContext: typeof AudioContext })
      .webkitAudioContext;
  const ctx = new AudioCtx();
  try {
    const decoded = await ctx.decodeAudioData(buffer.slice(0));
    if (decoded.numberOfChannels === 0 || decoded.length === 0) return null;

    const len = decoded.length;
    const samples = new Float32Array(len);
    const ch0 = decoded.getChannelData(0);
    if (decoded.numberOfChannels === 1) {
      samples.set(ch0);
    } else {
      const ch1 = decoded.getChannelData(1);
      for (let i = 0; i < len; i++) {
        samples[i] = (ch0[i] + ch1[i]) * 0.5;
      }
    }
    return { samples, sampleRate: decoded.sampleRate };
  } catch {
    return null;
  } finally {
    await ctx.close();
  }
}

/** RMS energy per WINDOW_SEC frame, normalized 0–1 against peak. */
export function computeEnergyEnvelope(
  samples: Float32Array,
  sampleRate: number,
): Float32Array {
  const frameSize = Math.max(1, Math.floor(sampleRate * WINDOW_SEC));
  const frameCount = Math.ceil(samples.length / frameSize);
  const energy = new Float32Array(frameCount);
  let peak = 0;

  for (let f = 0; f < frameCount; f++) {
    const start = f * frameSize;
    const end = Math.min(samples.length, start + frameSize);
    let sum = 0;
    for (let i = start; i < end; i++) {
      const v = samples[i];
      sum += v * v;
    }
    const rms = Math.sqrt(sum / Math.max(1, end - start));
    energy[f] = rms;
    if (rms > peak) peak = rms;
  }

  const norm = peak > 1e-8 ? peak : 1;
  for (let i = 0; i < energy.length; i++) {
    energy[i] /= norm;
  }
  return energy;
}

/**
 * Find keep ranges (speech) inside [inPoint, outPoint] after removing silence.
 * Times are in source seconds.
 */
export function findKeepRanges(
  energy: Float32Array,
  inPoint: number,
  outPoint: number,
  options: AutoEditOptions,
): TimeRange[] {
  const { silenceThreshold, minSilence, padding, trimEnds } = options;
  const duration = outPoint - inPoint;
  if (duration <= 0.05) return [{ start: inPoint, end: outPoint }];

  const startFrame = Math.floor(inPoint / WINDOW_SEC);
  const endFrame = Math.min(energy.length, Math.ceil(outPoint / WINDOW_SEC));

  // Mark silent frames within the clip window
  const silent = new Array<boolean>(Math.max(0, endFrame - startFrame)).fill(
    false,
  );
  for (let i = startFrame; i < endFrame; i++) {
    const e = i >= 0 && i < energy.length ? energy[i] : 0;
    silent[i - startFrame] = e < silenceThreshold;
  }

  // Find silence runs (in source seconds)
  type Run = { start: number; end: number };
  const silenceRuns: Run[] = [];
  let runStart = -1;
  for (let i = 0; i <= silent.length; i++) {
    const isSilent = i < silent.length && silent[i];
    if (isSilent && runStart < 0) runStart = i;
    if ((!isSilent || i === silent.length) && runStart >= 0) {
      const s = inPoint + runStart * WINDOW_SEC;
      const e = inPoint + i * WINDOW_SEC;
      silenceRuns.push({ start: s, end: Math.min(e, outPoint) });
      runStart = -1;
    }
  }

  // Decide which silence to cut
  const cutRuns = silenceRuns.filter((run) => {
    const len = run.end - run.start;
    const atStart = run.start <= inPoint + 0.02;
    const atEnd = run.end >= outPoint - 0.02;
    if (trimEnds && (atStart || atEnd) && len >= 0.12) return true;
    return len >= minSilence;
  });

  if (cutRuns.length === 0) {
    return [{ start: inPoint, end: outPoint }];
  }

  // Invert cuts → keepers, with padding (don't eat into speech)
  const keepers: TimeRange[] = [];
  let cursor = inPoint;
  for (const cut of cutRuns) {
    const keepEnd = Math.max(cursor, cut.start - padding);
    if (keepEnd - cursor >= 0.08) {
      keepers.push({ start: cursor, end: keepEnd });
    }
    cursor = Math.min(outPoint, cut.end + padding);
  }
  if (outPoint - cursor >= 0.08) {
    keepers.push({ start: cursor, end: outPoint });
  }

  // Merge overlapping / abutting keepers
  const merged: TimeRange[] = [];
  for (const k of keepers) {
    const last = merged[merged.length - 1];
    if (last && k.start <= last.end + 0.02) {
      last.end = Math.max(last.end, k.end);
    } else {
      merged.push({ ...k });
    }
  }

  return merged.length > 0 ? merged : [{ start: inPoint, end: outPoint }];
}

const energyCache = new Map<string, Float32Array>();

export async function analyzeProjectForAutoEdit(
  project: Project,
  options: AutoEditOptions,
  onProgress?: (label: string, ratio: number) => void,
  signal?: AbortSignal,
): Promise<AutoEditPreview> {
  const keepersByClip = new Map<string, TimeRange[]>();
  let originalDuration = 0;
  let newDuration = 0;
  let cutsRemoved = 0;
  let silenceRemoved = 0;

  const clips = [...project.clips].sort((a, b) => a.offset - b.offset);
  const mediaNeeded = new Map<string, MediaItem>();
  for (const clip of clips) {
    const media = project.media.find((m) => m.id === clip.mediaId);
    if (media) mediaNeeded.set(media.id, media);
  }

  let decoded = 0;
  const totalMedia = mediaNeeded.size || 1;
  const envelopes = new Map<string, Float32Array | null>();

  for (const [id, media] of mediaNeeded) {
    if (signal?.aborted) throw new DOMException("Cancelled", "AbortError");
    onProgress?.(`Listening to ${media.name}…`, decoded / totalMedia);

    let energy = energyCache.get(id) ?? null;
    if (!energy) {
      const audio = await decodeMediaAudio(media.url, signal);
      if (audio) {
        energy = computeEnergyEnvelope(audio.samples, audio.sampleRate);
        energyCache.set(id, energy);
      }
    }
    envelopes.set(id, energy);
    decoded += 1;
  }

  onProgress?.("Finding mistakes…", 0.9);

  for (const clip of clips) {
    const dur = clipDuration(clip);
    originalDuration += dur;
    const energy = envelopes.get(clip.mediaId);

    if (!energy) {
      // No audio — keep as-is
      keepersByClip.set(clip.id, [
        { start: clip.inPoint, end: clip.outPoint },
      ]);
      newDuration += dur;
      continue;
    }

    const keepers = findKeepRanges(
      energy,
      clip.inPoint,
      clip.outPoint,
      options,
    ).map((k) => ({
      start: k.start,
      end: k.end,
      // Convert source keep length considering speed
    }));

    keepersByClip.set(clip.id, keepers);
    const keptSource = keepers.reduce((s, k) => s + (k.end - k.start), 0);
    const keptTimeline = keptSource / clip.speed;
    newDuration += keptTimeline;
    silenceRemoved += Math.max(0, dur - keptTimeline);
    cutsRemoved += Math.max(0, keepers.length - 1);
    // Also count end trims as cuts for UX
    if (
      keepers.length > 0 &&
      (keepers[0].start > clip.inPoint + 0.05 ||
        keepers[keepers.length - 1].end < clip.outPoint - 0.05)
    ) {
      cutsRemoved += 1;
    }
  }

  onProgress?.("Ready", 1);

  return {
    originalDuration,
    newDuration,
    cutsRemoved,
    silenceRemoved,
    keepersByClip,
  };
}

/** Rebuild timeline clips from keeper ranges, ripple-closed. */
export function applyAutoEdit(
  project: Project,
  preview: AutoEditPreview,
): TimelineClip[] {
  const sorted = [...project.clips].sort((a, b) => a.offset - b.offset);
  const next: TimelineClip[] = [];
  let offset = 0;

  for (const clip of sorted) {
    const keepers = preview.keepersByClip.get(clip.id) ?? [
      { start: clip.inPoint, end: clip.outPoint },
    ];
    for (const k of keepers) {
      if (k.end - k.start < 0.05) continue;
      const piece: TimelineClip = {
        ...clip,
        id: uuid(),
        inPoint: k.start,
        outPoint: k.end,
        offset,
      };
      next.push(piece);
      offset += clipDuration(piece);
    }
  }

  return next;
}

export function clearAutoEditCache() {
  energyCache.clear();
}
