import type { FilterPreset } from "../types";

export const FILTER_CSS: Record<FilterPreset, string> = {
  none: "none",
  warm: "sepia(0.28) saturate(1.2) brightness(1.05)",
  cool: "saturate(0.9) hue-rotate(195deg) brightness(1.05)",
  mono: "grayscale(1) contrast(1.1)",
  vivid: "saturate(1.55) contrast(1.12)",
  fade: "contrast(0.88) brightness(1.08) saturate(0.75)",
};

export const FILTER_LABELS: Record<FilterPreset, string> = {
  none: "Original",
  warm: "Warm",
  cool: "Cool",
  mono: "Mono",
  vivid: "Vivid",
  fade: "Fade",
};
