const screen = document.getElementById("screen");
const toggle = document.getElementById("toggleCharge");
const levelInput = document.getElementById("level");
const percentEl = document.getElementById("percent");
const laPercent = document.getElementById("laPercent");
const statusBattery = document.getElementById("statusBattery");
const chargeLabel = document.getElementById("chargeLabel");
const watts = document.getElementById("watts");
const liveActivity = document.getElementById("liveActivity");
const ringProgress = document.getElementById("ringProgress");
const clock = document.getElementById("clock");
const fastBadge = document.getElementById("fastBadge");
const meters = document.getElementById("meters");
const voltageEl = document.getElementById("voltage");
const currentEl = document.getElementById("current");
const powerEl = document.getElementById("power");
const chargeSocket = document.getElementById("chargeSocket");
const flowerCanvas = document.getElementById("flowerField");
const flowerCtx = flowerCanvas.getContext("2d");

const CIRCUMFERENCE = 2 * Math.PI * 86;
ringProgress.style.strokeDasharray = String(CIRCUMFERENCE);

const PALETTE = [
  "#ff739e", "#ffb847", "#8cd1ff", "#b88cff", "#73ebb2",
  "#ff8c4d", "#ffd966", "#f25858", "#59bfff", "#ffe08a",
];

const SCENES = [
  "flower", "rocket", "drone", "train", "ferrari", "scooter",
  "fish", "sparrows", "snake", "sunrise", "popcorn", "beach",
];

const SCENE_TITLE = {
  flower: "Flowers",
  rocket: "Rocket",
  drone: "Drone",
  train: "Train",
  ferrari: "Ferrari",
  scooter: "Scooter",
  fish: "Fish",
  sparrows: "Sparrows",
  snake: "Snake",
  sunrise: "Sunrise",
  popcorn: "Popcorn",
  beach: "Sea beach",
};

let charging = false;
let level = Number(levelInput.value);
let particles = [];
let scene = randomScene();
let nextSceneAt = performance.now() + 4000;
let sceneLabelEl = null;

function ensureSceneLabel() {
  if (sceneLabelEl) return sceneLabelEl;
  sceneLabelEl = document.createElement("div");
  sceneLabelEl.className = "scene-label";
  screen.appendChild(sceneLabelEl);
  return sceneLabelEl;
}

function randomScene(exclude) {
  let next = SCENES[(Math.random() * SCENES.length) | 0];
  while (exclude && next === exclude && SCENES.length > 1) {
    next = SCENES[(Math.random() * SCENES.length) | 0];
  }
  return next;
}

function tickClock() {
  const now = new Date();
  clock.textContent = now.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function estimateElectricals(pct, isCharging) {
  if (!isCharging) return { v: 0, a: 0, w: 0, fast: false, mode: "Unplugged", label: "ON BATTERY" };
  if (pct >= 100) return { v: 5.0, a: 0.05, w: 0.3, fast: false, mode: "Fully charged", label: "FULLY CHARGED" };
  const jV = (Math.random() - 0.5) * 0.12;
  const jA = (Math.random() - 0.5) * 0.1;
  let v; let a; let fast; let mode;
  if (pct < 50) { v = 9.2 + jV; a = 3.35 + jA; fast = true; mode = "Fast charging"; }
  else if (pct < 80) { v = 9.0 + jV; a = 2.45 + jA; fast = true; mode = "Fast charging"; }
  else if (pct < 92) { v = 5.2 + jV * 0.4; a = 1.15 + jA * 0.4; fast = false; mode = "Standard charge"; }
  else { v = 5.1 + jV * 0.25; a = 0.55 + jA * 0.25; fast = false; mode = "Trickle charge"; }
  v = Math.max(4.8, v); a = Math.max(0.05, a);
  return {
    v: Math.round(v * 10) / 10,
    a: Math.round(a * 100) / 100,
    w: Math.round(v * a * 10) / 10,
    fast,
    mode,
    label: fast ? "FAST CHARGING" : "CHARGING",
  };
}

function resizeCanvas() {
  const rect = screen.getBoundingClientRect();
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  flowerCanvas.width = Math.floor(rect.width * dpr);
  flowerCanvas.height = Math.floor(rect.height * dpr);
  flowerCanvas.style.width = `${rect.width}px`;
  flowerCanvas.style.height = `${rect.height}px`;
  flowerCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function spawn(count) {
  const w = flowerCanvas.clientWidth;
  const h = flowerCanvas.clientHeight;
  for (let i = 0; i < count; i += 1) {
    particles.push({
      born: performance.now(),
      life: 2000 + Math.random() * 2000,
      rise: h * (0.45 + Math.random() * 0.5),
      drift: (Math.random() - 0.5) * w * 0.8,
      amp: 10 + Math.random() * 24,
      freq: 0.6 + Math.random() * 1.6,
      phase: Math.random() * Math.PI * 2,
      spin: (Math.random() - 0.5) * 3,
      scale: 0.5 + Math.random() * 0.85,
      color: PALETTE[(Math.random() * PALETTE.length) | 0],
      scene,
      petals: 4 + ((Math.random() * 3) | 0),
    });
  }
  if (particles.length > 160) particles.splice(0, particles.length - 160);
}

function pos(p, t, sx, sy, w) {
  const tt = t;
  switch (p.scene) {
    case "rocket":
      return [sx + Math.sin(t * 6 + p.phase) * 10, sy - tt * p.rise * 1.15];
    case "drone":
      return [sx + p.drift * tt, sy - tt * p.rise * 0.85 + Math.sin(t * Math.PI * 4 + p.phase) * 16];
    case "train":
    case "ferrari":
    case "scooter":
      return [sx + Math.sign(p.drift || 1) * Math.abs(p.drift) * tt * 1.35, sy - 20 - Math.sin(tt * Math.PI) * 12 - tt * 28];
    case "fish":
      return [sx + p.drift * tt, sy - tt * p.rise * 0.7 + Math.sin(t * Math.PI * 3 + p.phase) * p.amp];
    case "sparrows":
      return [sx + p.drift * tt, sy - tt * p.rise + Math.sin(t * Math.PI * 8 + p.phase) * 10];
    case "snake":
      return [sx + Math.sin(t * Math.PI * 5 + p.phase) * p.amp * 1.6, sy - tt * p.rise];
    case "sunrise": {
      const arc = tt * Math.PI;
      return [sx + Math.cos(arc + p.phase) * p.amp * 2.2, sy - Math.sin(arc) * p.rise * 0.85];
    }
    case "beach":
      return [sx + p.drift * tt, sy - 40 - tt * p.rise * 0.45 + Math.sin(t * Math.PI * 2 + p.phase) * 14];
    default: {
      const sway = Math.sin(t * Math.PI * 2 * p.freq + p.phase) * p.amp;
      return [sx + p.drift * tt + sway, sy - tt * p.rise];
    }
  }
}

function drawShape(ctx, p, rot) {
  ctx.save();
  ctx.rotate(rot);
  ctx.fillStyle = p.color;
  ctx.strokeStyle = p.color;
  ctx.lineWidth = 1.4;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  switch (p.scene) {
    case "flower": {
      for (let i = 0; i < p.petals; i += 1) {
        const a = (i / p.petals) * Math.PI * 2 - Math.PI / 2;
        ctx.beginPath();
        ctx.ellipse(Math.cos(a) * 5, Math.sin(a) * 5, 2.2, 3.2, a, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.beginPath(); ctx.arc(0, 0, 1.5, 0, Math.PI * 2); ctx.fillStyle = "#ffe08a"; ctx.fill();
      break;
    }
    case "rocket": {
      ctx.beginPath();
      ctx.moveTo(0, -7); ctx.lineTo(4, 2); ctx.lineTo(2, 2); ctx.lineTo(3, 6);
      ctx.lineTo(-3, 6); ctx.lineTo(-2, 2); ctx.lineTo(-4, 2); ctx.closePath(); ctx.fill();
      break;
    }
    case "drone": {
      ctx.beginPath(); ctx.ellipse(0, 0, 3, 2, 0, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(-5.5, -3, 2.4, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(5.5, -3, 2.4, 0, Math.PI * 2); ctx.fill();
      break;
    }
    case "train": {
      roundRect(ctx, -7, -3, 14, 7, 1.5); ctx.fill();
      ctx.beginPath(); ctx.arc(-3.5, 4.5, 1.6, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(3.5, 4.5, 1.6, 0, Math.PI * 2); ctx.fill();
      break;
    }
    case "ferrari": {
      ctx.beginPath();
      ctx.moveTo(-8, 2); ctx.lineTo(-6, -2); ctx.lineTo(-2, -4); ctx.lineTo(3, -4);
      ctx.lineTo(7, -1); ctx.lineTo(8, 2); ctx.closePath(); ctx.fill();
      ctx.beginPath(); ctx.arc(-3.5, 2.5, 1.5, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(4, 2.5, 1.5, 0, Math.PI * 2); ctx.fill();
      break;
    }
    case "scooter": {
      ctx.beginPath(); ctx.arc(-4.5, 3.5, 1.8, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(4.5, 3.5, 1.8, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.moveTo(-4, 3); ctx.lineTo(4, 3); ctx.lineTo(5, -4); ctx.lineTo(3, -5); ctx.stroke();
      break;
    }
    case "fish": {
      ctx.beginPath(); ctx.ellipse(-1, 0, 4.5, 2.5, 0, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.moveTo(3, 0); ctx.lineTo(7, -3); ctx.lineTo(7, 3); ctx.closePath(); ctx.fill();
      break;
    }
    case "sparrows": {
      ctx.beginPath();
      ctx.moveTo(-6, 0);
      ctx.quadraticCurveTo(-3, -5, 0, -2);
      ctx.quadraticCurveTo(3, -5, 6, 0);
      ctx.quadraticCurveTo(2, 1, 0, 1);
      ctx.quadraticCurveTo(-2, 1, -6, 0);
      ctx.fill();
      break;
    }
    case "snake": {
      ctx.beginPath();
      ctx.moveTo(-7, 2);
      ctx.bezierCurveTo(-5, -4, -3, 4, -2, -2);
      ctx.bezierCurveTo(0, -6, 2, 5, 4, 1);
      ctx.bezierCurveTo(6, -3, 7, 2, 8, -2);
      ctx.stroke();
      break;
    }
    case "sunrise": {
      ctx.beginPath(); ctx.arc(0, 0, 3.2, 0, Math.PI * 2); ctx.fill();
      for (let i = 0; i < 8; i += 1) {
        const a = (i / 8) * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(Math.cos(a) * 4, Math.sin(a) * 4);
        ctx.lineTo(Math.cos(a) * 7, Math.sin(a) * 7);
        ctx.stroke();
      }
      break;
    }
    case "popcorn": {
      ctx.beginPath(); ctx.arc(-1, -2, 2.4, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(1.5, 0, 2.5, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(-2, 1, 2.2, 0, Math.PI * 2); ctx.fill();
      break;
    }
    case "beach": {
      ctx.beginPath();
      ctx.moveTo(0, -5);
      ctx.quadraticCurveTo(6, -3, 6, 3);
      ctx.quadraticCurveTo(0, 6, -6, 3);
      ctx.quadraticCurveTo(-6, -3, 0, -5);
      ctx.fill();
      break;
    }
    default: break;
  }
  ctx.restore();
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function drawBackdrop(ctx, w, h) {
  if (scene === "sunrise") {
    const g = ctx.createRadialGradient(w * 0.5, h * 0.42, 4, w * 0.5, h * 0.42, 90);
    g.addColorStop(0, "rgba(255,160,40,0.5)");
    g.addColorStop(0.5, "rgba(255,210,80,0.16)");
    g.addColorStop(1, "rgba(255,160,40,0)");
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(w * 0.5, h * 0.42, 90, 0, Math.PI * 2); ctx.fill();
  }
  if (scene === "beach") {
    ctx.fillStyle = "rgba(40,130,200,0.22)";
    ctx.beginPath();
    ctx.moveTo(0, h * 0.72);
    ctx.quadraticCurveTo(w * 0.5, h * 0.68, w, h * 0.74);
    ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath(); ctx.fill();
  }
}

function paint(now) {
  const w = flowerCanvas.clientWidth;
  const h = flowerCanvas.clientHeight;
  flowerCtx.clearRect(0, 0, w, h);
  if (!charging) return;

  if (now >= nextSceneAt) {
    scene = randomScene(scene);
    nextSceneAt = now + 3200 + Math.random() * 2000;
    spawn(12 + ((Math.random() * 8) | 0));
    const label = ensureSceneLabel();
    label.textContent = SCENE_TITLE[scene].toUpperCase();
    label.hidden = false;
  }

  drawBackdrop(flowerCtx, w, h);
  const sx = w * 0.5;
  const sy = h - 14;
  particles = particles.filter((p) => now - p.born < p.life);
  for (const p of particles) {
    const t = (now - p.born) / p.life;
    const [x, y] = pos(p, t, sx, sy, w);
    const opacity = Math.max(0, 1 - t ** 1.5);
    const scale = p.scale * (0.4 + 0.6 * (1 - Math.abs(t - 0.3)));
    flowerCtx.save();
    flowerCtx.globalAlpha = opacity;
    flowerCtx.translate(x, y);
    flowerCtx.scale(scale, scale);
    drawShape(flowerCtx, p, p.spin * t * Math.PI * 2);
    flowerCtx.restore();
  }
  flowerCtx.globalAlpha = 1;
}

function loop(now) {
  if (charging && Math.random() < 0.6) spawn(1 + ((Math.random() * 3) | 0));
  paint(now || performance.now());
  requestAnimationFrame(loop);
}

function render() {
  const pct = Math.round(level);
  const elec = estimateElectricals(pct, charging);
  percentEl.textContent = String(pct);
  laPercent.textContent = `${pct}%`;
  statusBattery.textContent = String(pct);
  ringProgress.style.strokeDashoffset = String(CIRCUMFERENCE * (1 - level / 100));
  screen.classList.toggle("is-charging", charging);
  liveActivity.hidden = !charging;
  chargeSocket.hidden = !charging;
  meters.hidden = !charging;
  toggle.setAttribute("aria-pressed", charging ? "true" : "false");
  toggle.textContent = charging ? "Unplug charger" : "Connect charger";

  const label = ensureSceneLabel();
  if (!charging) {
    chargeLabel.textContent = "ON BATTERY";
    watts.textContent = "Plug in to wake Aura";
    fastBadge.hidden = true;
    particles = [];
    label.hidden = true;
    flowerCtx.clearRect(0, 0, flowerCanvas.clientWidth, flowerCanvas.clientHeight);
    return;
  }

  label.hidden = false;
  label.textContent = SCENE_TITLE[scene].toUpperCase();
  chargeLabel.textContent = elec.label;
  voltageEl.textContent = `${elec.v.toFixed(1)} V`;
  currentEl.textContent = `${elec.a.toFixed(2)} A`;
  powerEl.textContent = `${elec.w.toFixed(0)} W`;
  fastBadge.hidden = false;
  if (elec.fast) {
    fastBadge.textContent = "FAST CHARGING CONFIRMED";
    fastBadge.classList.remove("is-standard");
    watts.textContent = `Fast charging confirmed · ${elec.w.toFixed(0)} W`;
  } else {
    fastBadge.textContent = elec.mode.toUpperCase();
    fastBadge.classList.add("is-standard");
    watts.textContent = pct >= 100 ? `Holding 100% · ${elec.v.toFixed(1)} V` : `${elec.mode} · ${elec.w.toFixed(0)} W`;
  }
}

toggle.addEventListener("click", () => {
  charging = !charging;
  if (charging) {
    scene = randomScene();
    nextSceneAt = performance.now() + 4000;
    spawn(16);
  }
  render();
});

levelInput.addEventListener("input", () => {
  level = Number(levelInput.value);
  render();
});

setInterval(() => {
  if (charging && level < 100) {
    level = Math.min(100, level + 0.35);
    levelInput.value = String(Math.round(level));
  }
  render();
}, 1200);

window.addEventListener("resize", resizeCanvas);
tickClock();
setInterval(tickClock, 30_000);
resizeCanvas();
render();
requestAnimationFrame(loop);
