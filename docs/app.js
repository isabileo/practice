const stage = document.getElementById("stage");
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
const sceneCaption = document.getElementById("sceneCaption");
const flowerCanvas = document.getElementById("flowerField");
const flowerCtx = flowerCanvas.getContext("2d");

const CIRCUMFERENCE = 2 * Math.PI * 86;
ringProgress.style.strokeDasharray = String(CIRCUMFERENCE);

const PALETTE = [
  "#ff739e", "#ffb847", "#8cd1ff", "#b88cff", "#73ebb2",
  "#ff8c4d", "#ffd966", "#f25858", "#59bfff", "#ffe08a", "#ff6bcb", "#7dffb3",
];

const SCENES = [
  "flower", "rocket", "drone", "train", "ferrari", "scooter",
  "fish", "sparrows", "snake", "sunrise", "popcorn", "beach",
];

const SCENE_TITLE = {
  flower: "Flowers", rocket: "Rocket", drone: "Drone", train: "Train",
  ferrari: "Ferrari", scooter: "Scooter", fish: "Fish", sparrows: "Sparrows",
  snake: "Snake", sunrise: "Sunrise", popcorn: "Popcorn", beach: "Sea beach",
};

const MOTIONS = ["rise", "spiral", "fountain", "swirl", "zigzag", "burst", "wave", "scatter"];

let charging = false;
let level = Number(levelInput.value);
let particles = [];
let scene = "flower";
let motion = "rise";
let nextSceneAt = Infinity;
let sceneLabelEl = null;
let animating = false;

function pick(arr, exclude) {
  let next = arr[(Math.random() * arr.length) | 0];
  let guard = 0;
  while (exclude != null && next === exclude && arr.length > 1 && guard++ < 20) {
    next = arr[(Math.random() * arr.length) | 0];
  }
  return next;
}

function rand(a, b) {
  return a + Math.random() * (b - a);
}

function ensureSceneLabel() {
  if (sceneLabelEl) return sceneLabelEl;
  sceneLabelEl = document.createElement("div");
  sceneLabelEl.className = "scene-label";
  screen.appendChild(sceneLabelEl);
  return sceneLabelEl;
}

function resizeCanvas() {
  const rect = screen.getBoundingClientRect();
  if (rect.width < 2 || rect.height < 2) return false;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  flowerCanvas.width = Math.floor(rect.width * dpr);
  flowerCanvas.height = Math.floor(rect.height * dpr);
  flowerCanvas.style.width = `${rect.width}px`;
  flowerCanvas.style.height = `${rect.height}px`;
  flowerCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return true;
}

function spawn(count) {
  const w = flowerCanvas.clientWidth || screen.clientWidth || 200;
  const h = flowerCanvas.clientHeight || screen.clientHeight || 420;
  for (let i = 0; i < count; i += 1) {
    particles.push({
      born: performance.now(),
      life: rand(1400, 3000),
      rise: h * rand(0.45, 0.95),
      drift: (Math.random() - 0.5) * w * rand(0.55, 1.05),
      amp: rand(8, 34),
      freq: rand(0.5, 2.8),
      phase: Math.random() * Math.PI * 2,
      spin: rand(-3, 3),
      scale: rand(0.5, 1.35),
      color: pick(PALETTE),
      scene,
      motion: Math.random() < 0.6 ? motion : pick(MOTIONS),
      petals: 4 + ((Math.random() * 4) | 0),
    });
  }
  if (particles.length > 180) particles.splice(0, particles.length - 180);
}

function reshuffle(hard = true) {
  scene = pick(SCENES, scene);
  motion = pick(MOTIONS, motion);
  if (hard) particles = [];
  nextSceneAt = performance.now() + rand(1600, 2600);
  spawn(18 + ((Math.random() * 12) | 0));
  const label = ensureSceneLabel();
  label.hidden = !charging;
  label.textContent = `${SCENE_TITLE[scene]} · ${motion}`.toUpperCase();
  if (sceneCaption) sceneCaption.textContent = `${SCENE_TITLE[scene]} · ${motion}`;
}

/** Show small app screen + start animations only after charger connects. */
function connectCharger() {
  charging = true;
  animating = false;
  particles = [];
  stage.classList.add("is-charging-live");
  renderMeters();

  // Wait until the phone is laid out (it was display:none), then burst-animate.
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      if (!charging) return;
      resizeCanvas();
      reshuffle(true);
      spawn(20);
      animating = true;
      renderMeters();
    });
  });
}

function disconnectCharger() {
  charging = false;
  animating = false;
  particles = [];
  nextSceneAt = Infinity;
  stage.classList.remove("is-charging-live");
  flowerCtx.clearRect(0, 0, flowerCanvas.width || 1, flowerCanvas.height || 1);
  const label = ensureSceneLabel();
  label.hidden = true;
  renderMeters();
}

function tickClock() {
  clock.textContent = new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function estimateElectricals(pct, on) {
  if (!on) return { v: 0, a: 0, w: 0, fast: false, mode: "Unplugged", label: "ON BATTERY" };
  if (pct >= 100) return { v: 5.0, a: 0.05, w: 0.3, fast: false, mode: "Fully charged", label: "FULLY CHARGED" };
  const jV = rand(-0.08, 0.08);
  const jA = rand(-0.08, 0.08);
  let v;
  let a;
  let fast;
  let mode;
  if (pct < 50) {
    v = 9.2 + jV;
    a = 3.35 + jA;
    fast = true;
    mode = "Fast charging";
  } else if (pct < 80) {
    v = 9.0 + jV;
    a = 2.45 + jA;
    fast = true;
    mode = "Fast charging";
  } else if (pct < 92) {
    v = 5.2 + jV * 0.4;
    a = 1.15 + jA * 0.4;
    fast = false;
    mode = "Standard charge";
  } else {
    v = 5.1 + jV * 0.25;
    a = 0.55 + jA * 0.25;
    fast = false;
    mode = "Trickle charge";
  }
  v = Math.max(4.8, v);
  a = Math.max(0.05, a);
  return {
    v: Math.round(v * 10) / 10,
    a: Math.round(a * 100) / 100,
    w: Math.round(v * a * 10) / 10,
    fast,
    mode,
    label: fast ? "FAST CHARGING" : "CHARGING",
  };
}

function pos(p, t, sx, sy) {
  const tt = t;
  switch (p.motion) {
    case "spiral": {
      const r = p.amp * 0.3 + tt * p.amp * 2.4;
      const a = p.phase + t * Math.PI * 2 * p.freq;
      return [sx + Math.cos(a) * r, sy - tt * p.rise];
    }
    case "fountain":
      return [sx + p.drift * tt, sy - (4 * p.rise * 0.55 * tt * (1 - tt) + tt * p.rise * 0.4)];
    case "swirl": {
      const a = p.phase + t * Math.PI * 2 * Math.max(0.7, p.freq);
      const r = tt * p.rise * 0.35;
      return [sx + Math.cos(a) * r + p.drift * 0.2, sy - tt * p.rise * 0.8 + Math.sin(a) * 10];
    }
    case "zigzag":
      return [sx + Math.sin(t * Math.PI * 6 + p.phase) * p.amp * 1.5, sy - tt * p.rise];
    case "burst": {
      const a = p.phase;
      const d = tt * p.rise;
      return [sx + Math.cos(a) * d * 0.5, sy - Math.abs(Math.sin(a)) * d - tt * 30];
    }
    case "wave":
      return [sx + p.drift * tt, sy - tt * p.rise * 0.75 + Math.sin(t * Math.PI * 3 + p.phase) * p.amp];
    case "scatter":
      return [sx + p.drift * Math.pow(tt, 0.7), sy - tt * p.rise * 0.95];
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
  ctx.lineWidth = 1.3;
  ctx.lineCap = "round";
  switch (p.scene) {
    case "flower":
      for (let i = 0; i < p.petals; i += 1) {
        const a = (i / p.petals) * Math.PI * 2 - Math.PI / 2;
        ctx.beginPath();
        ctx.ellipse(Math.cos(a) * 5, Math.sin(a) * 5, 2.1, 3.1, a, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.beginPath();
      ctx.arc(0, 0, 1.4, 0, Math.PI * 2);
      ctx.fillStyle = "#ffe08a";
      ctx.fill();
      break;
    case "rocket":
      ctx.beginPath();
      ctx.moveTo(0, -7);
      ctx.lineTo(4, 2);
      ctx.lineTo(2, 2);
      ctx.lineTo(3, 6);
      ctx.lineTo(-3, 6);
      ctx.lineTo(-2, 2);
      ctx.lineTo(-4, 2);
      ctx.closePath();
      ctx.fill();
      break;
    case "drone":
      ctx.beginPath();
      ctx.ellipse(0, 0, 3, 2, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(-5.5, -3, 2.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(5.5, -3, 2.3, 0, Math.PI * 2);
      ctx.fill();
      break;
    case "train":
      roundRect(ctx, -7, -3, 14, 7, 1.4);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(-3.5, 4.5, 1.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(3.5, 4.5, 1.5, 0, Math.PI * 2);
      ctx.fill();
      break;
    case "ferrari":
      ctx.beginPath();
      ctx.moveTo(-8, 2);
      ctx.lineTo(-6, -2);
      ctx.lineTo(-2, -4);
      ctx.lineTo(3, -4);
      ctx.lineTo(7, -1);
      ctx.lineTo(8, 2);
      ctx.closePath();
      ctx.fill();
      ctx.beginPath();
      ctx.arc(-3.5, 2.5, 1.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(4, 2.5, 1.4, 0, Math.PI * 2);
      ctx.fill();
      break;
    case "scooter":
      ctx.beginPath();
      ctx.arc(-4.5, 3.5, 1.7, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(4.5, 3.5, 1.7, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(-4, 3);
      ctx.lineTo(4, 3);
      ctx.lineTo(5, -4);
      ctx.lineTo(3, -5);
      ctx.stroke();
      break;
    case "fish":
      ctx.beginPath();
      ctx.ellipse(-1, 0, 4.3, 2.4, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(3, 0);
      ctx.lineTo(7, -3);
      ctx.lineTo(7, 3);
      ctx.closePath();
      ctx.fill();
      break;
    case "sparrows":
      ctx.beginPath();
      ctx.moveTo(-6, 0);
      ctx.quadraticCurveTo(-3, -5, 0, -2);
      ctx.quadraticCurveTo(3, -5, 6, 0);
      ctx.quadraticCurveTo(2, 1, 0, 1);
      ctx.quadraticCurveTo(-2, 1, -6, 0);
      ctx.fill();
      break;
    case "snake":
      ctx.beginPath();
      ctx.moveTo(-7, 2);
      ctx.bezierCurveTo(-5, -4, -3, 4, -2, -2);
      ctx.bezierCurveTo(0, -6, 2, 5, 4, 1);
      ctx.bezierCurveTo(6, -3, 7, 2, 8, -2);
      ctx.stroke();
      break;
    case "sunrise":
      ctx.beginPath();
      ctx.arc(0, 0, 3, 0, Math.PI * 2);
      ctx.fill();
      for (let i = 0; i < 8; i += 1) {
        const a = (i / 8) * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(Math.cos(a) * 4, Math.sin(a) * 4);
        ctx.lineTo(Math.cos(a) * 7, Math.sin(a) * 7);
        ctx.stroke();
      }
      break;
    case "popcorn":
      ctx.beginPath();
      ctx.arc(-1, -2, 2.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(1.5, 0, 2.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(-2, 1, 2.1, 0, Math.PI * 2);
      ctx.fill();
      break;
    case "beach":
      ctx.beginPath();
      ctx.moveTo(0, -5);
      ctx.quadraticCurveTo(6, -3, 6, 3);
      ctx.quadraticCurveTo(0, 6, -6, 3);
      ctx.quadraticCurveTo(-6, -3, 0, -5);
      ctx.fill();
      break;
    default:
      break;
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
    const g = ctx.createRadialGradient(w * 0.5, h * 0.4, 3, w * 0.5, h * 0.4, 70);
    g.addColorStop(0, "rgba(255,160,40,0.55)");
    g.addColorStop(0.55, "rgba(255,210,80,0.14)");
    g.addColorStop(1, "rgba(255,160,40,0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(w * 0.5, h * 0.4, 70, 0, Math.PI * 2);
    ctx.fill();
  }
  if (scene === "beach") {
    ctx.fillStyle = "rgba(40,130,200,0.22)";
    ctx.beginPath();
    ctx.moveTo(0, h * 0.72);
    ctx.quadraticCurveTo(w * 0.5, h * 0.67, w, h * 0.74);
    ctx.lineTo(w, h);
    ctx.lineTo(0, h);
    ctx.closePath();
    ctx.fill();
  }
}

function paint(now) {
  const w = flowerCanvas.clientWidth;
  const h = flowerCanvas.clientHeight;
  flowerCtx.clearRect(0, 0, w || 1, h || 1);
  if (!charging || !animating || !w) return;

  if (now >= nextSceneAt) reshuffle(true);

  drawBackdrop(flowerCtx, w, h);
  const sx = w * 0.5;
  const sy = h - 12;
  particles = particles.filter((p) => now - p.born < p.life);
  for (const p of particles) {
    const t = (now - p.born) / p.life;
    const [x, y] = pos(p, t, sx, sy);
    const opacity = Math.max(0, 1 - t ** 1.45);
    const scale = p.scale * (0.35 + 0.7 * (1 - Math.abs(t - 0.32)));
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
  if (charging && animating && Math.random() < 0.75) {
    spawn(1 + ((Math.random() * 4) | 0));
  }
  paint(now || performance.now());
  requestAnimationFrame(loop);
}

function renderMeters() {
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

  if (!charging) {
    chargeLabel.textContent = "ON BATTERY";
    watts.textContent = "Waiting for charger…";
    fastBadge.hidden = true;
    return;
  }

  chargeLabel.textContent = elec.label;
  voltageEl.textContent = `${elec.v.toFixed(1)} V`;
  currentEl.textContent = `${elec.a.toFixed(2)} A`;
  powerEl.textContent = `${elec.w.toFixed(0)} W`;
  fastBadge.hidden = false;
  if (elec.fast) {
    fastBadge.textContent = "FAST CHARGING CONFIRMED";
    fastBadge.classList.remove("is-standard");
    watts.textContent = `Fast · ${elec.w.toFixed(0)} W`;
  } else {
    fastBadge.textContent = elec.mode.toUpperCase();
    fastBadge.classList.add("is-standard");
    watts.textContent =
      pct >= 100 ? `100% · ${elec.v.toFixed(1)} V` : `${elec.mode} · ${elec.w.toFixed(0)} W`;
  }
}

toggle.addEventListener("click", () => {
  if (charging) disconnectCharger();
  else connectCharger();
});

levelInput.addEventListener("input", () => {
  level = Number(levelInput.value);
  renderMeters();
});

setInterval(() => {
  if (charging && level < 100) {
    level = Math.min(100, level + 0.35);
    levelInput.value = String(Math.round(level));
    renderMeters();
  }
}, 1200);

window.addEventListener("resize", () => {
  if (charging) resizeCanvas();
});

tickClock();
setInterval(tickClock, 30_000);
disconnectCharger();
requestAnimationFrame(loop);
