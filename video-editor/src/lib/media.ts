export async function loadMediaFromFile(file: File): Promise<{
  url: string;
  duration: number;
  width: number;
  height: number;
  thumbnail: string;
}> {
  const url = URL.createObjectURL(file);
  const video = document.createElement("video");
  video.preload = "metadata";
  video.muted = true;
  video.playsInline = true;
  video.src = url;

  await new Promise<void>((resolve, reject) => {
    video.onloadedmetadata = () => resolve();
    video.onerror = () => reject(new Error(`Could not load ${file.name}`));
  });

  const duration = video.duration || 0;
  const width = video.videoWidth || 1280;
  const height = video.videoHeight || 720;

  // Seek near the start for a thumbnail
  const seekTo = Math.min(0.1, duration * 0.05);
  await new Promise<void>((resolve) => {
    const onSeeked = () => {
      video.removeEventListener("seeked", onSeeked);
      resolve();
    };
    video.addEventListener("seeked", onSeeked);
    video.currentTime = seekTo;
    // Fallback if already at seek position
    if (video.readyState >= 2 && Math.abs(video.currentTime - seekTo) < 0.05) {
      resolve();
    }
  });

  const canvas = document.createElement("canvas");
  const tw = 160;
  const th = Math.round((tw * height) / width) || 90;
  canvas.width = tw;
  canvas.height = th;
  const ctx = canvas.getContext("2d");
  let thumbnail = "";
  if (ctx) {
    ctx.drawImage(video, 0, 0, tw, th);
    thumbnail = canvas.toDataURL("image/jpeg", 0.7);
  }

  video.removeAttribute("src");
  video.load();

  return { url, duration, width, height, thumbnail };
}
