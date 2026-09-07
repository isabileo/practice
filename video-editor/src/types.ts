export type FilterPreset =
  | "none"
  | "warm"
  | "cool"
  | "mono"
  | "vivid"
  | "fade";

export type MediaItem = {
  id: string;
  name: string;
  url: string;
  duration: number;
  width: number;
  height: number;
  thumbnail: string;
};

export type TimelineClip = {
  id: string;
  mediaId: string;
  /** Source in-point (seconds) */
  inPoint: number;
  /** Source out-point (seconds) */
  outPoint: number;
  /** Position on the timeline (seconds) */
  offset: number;
  volume: number;
  speed: number;
  filter: FilterPreset;
};

export type TextOverlay = {
  id: string;
  text: string;
  start: number;
  end: number;
  x: number;
  y: number;
  fontSize: number;
  color: string;
};

export type Project = {
  media: MediaItem[];
  clips: TimelineClip[];
  texts: TextOverlay[];
};

export function clipDuration(clip: TimelineClip): number {
  return Math.max(0, (clip.outPoint - clip.inPoint) / clip.speed);
}

export function projectDuration(clips: TimelineClip[], texts: TextOverlay[]): number {
  const clipEnd = clips.reduce(
    (max, c) => Math.max(max, c.offset + clipDuration(c)),
    0,
  );
  const textEnd = texts.reduce((max, t) => Math.max(max, t.end), 0);
  return Math.max(clipEnd, textEnd, 0.1);
}

export function clipAtTime(
  clips: TimelineClip[],
  time: number,
): TimelineClip | null {
  for (const clip of clips) {
    const end = clip.offset + clipDuration(clip);
    if (time >= clip.offset && time < end) return clip;
  }
  return null;
}

export function sourceTimeForClip(clip: TimelineClip, timelineTime: number): number {
  const local = Math.max(0, timelineTime - clip.offset);
  return clip.inPoint + local * clip.speed;
}
