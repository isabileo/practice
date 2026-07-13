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

const PALETTE = ["#ff739e", "#ffb847", "#8cd1ff", "#b88cff", "#73ebb2", "#ff8c4d", "#ffd966"];

let charging = false;
let level = Number(levelInput.value);
let flowers = [];
let animId = 0;

function tickClock() {
  const now = new Date();
  clock.textContent = now.toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
}

/** Typical iPhone 17 Pro Max USB-PD curve for the demo meters. */
function estimateElectricals(pct, isCharging) {
  if (!isCharging) {
    return { v: 0, a: 0, w: 0, fast: false, mode: "Unplugged", label: "ON BATTERY" };
  }
  if (pct >= 100) {
    return { v: 5.0, a: 0.05, w: 0.3, fast: false, mode: "Fully charged", label: "FULLY CHARGED" };
  }
  const jV = (Math.random() - 0.5) * 0.12;
  const jA = (Math.random() - 0.5) * 0.1;
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

function resizeCanvas() {
  const rect = screen.getBoundingClientRect();
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  flowerCanvas.width = Math.floor(rect.width * dpr);
  flowerCanvas.height = Math.floor(rect.height * dpr);
  flowerCanvas.style.width = `${rect.width}px`;
  flowerCanvas.style.height = `${rect.height}px`;
  flowerCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function spawnFlowers(count) {
  const w = flowerCanvas.clientWidth;
  const h = flowerCanvas.clientHeight;
  for (let i = 0; i < count; i += 1) {
    flowers.push({
      born: performance.now(),
      life: 2200 + Math.random() * 1800,
      rise: h * (0.55 + Math.random() * 0.4),
      drift: (Math.random() - 0.5) * w * 0.7,
      sway: 8 + Math.random() * 22,
      freq: 0.8 + Math.random() * 1.1,
      phase: Math.random() * Math.PI * 2,
      spin: (Math.random() - 0.5) * 2.4,
      scale: 0.5 + Math.random() * 0.75,
      color: PALETTE[(Math.random() * PALETTE.length) | 0],
    });
  }
  if (flowers.length > 140) flowers.splice(0, flowers.length - 140);
}

function drawFlower(ctx, x, y, scale, color, rot) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rot);
  ctx.scale(scale, scale);
  for (let i = 0; i < 5; i += 1) {
    const angle = (i / 5) * Math.PI * 2 - Math.PI / 2;
    const cx = Math.cos(angle) * 5.2;
    const cy = Math.sin(angle) * 5.2;
    ctx.beginPath();
    ctx.ellipse(cx, cy, 2.4, 3.4, angle, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
  }
  ctx.beginPath();
  ctx.arc(0, 0, 1.6, 0, Math.PI * 2);
  ctx.fillStyle = "#ffe08a";
  ctx.fill();
  ctx.restore();
}

function paintFlowers(now) {
  const w = flowerCanvas.clientWidth;
  const h = flowerCanvas.clientHeight;
  flowerCtx.clearRect(0, 0, w, h);
  if (!charging) return;

  const socketX = w * 0.5;
  const socketY = h - 14;

  flowers = flowers.filter((f) => now - f.born < f.life);
  for (const f of flowers) {
    const t = (now - f.born) / f.life;
    const y = socketY - t * f.rise;
    const sway = Math.sin(t * Math.PI * 2 * f.freq + f.phase) * f.sway;
    const x = socketX + f.drift * t + sway;
    const opacity = 1 - t ** 1.55;
    const scale = f.scale * (0.35 + 0.65 * (1 - Math.abs(t - 0.35)));
    flowerCtx.globalAlpha = Math.max(0, opacity);
    drawFlower(flowerCtx, x, y, scale, f.color, f.spin * t * Math.PI * 2);
  }
  flowerCtx.globalAlpha = 1;
}

function flowerLoop(now) {
  if (charging && Math.random() < 0.55) spawnFlowers(1 + ((Math.random() * 3) | 0));
  paintFlowers(now);
  animId = requestAnimationFrame(flowerLoop);
}

function render() {
  const pct = Math.round(level);
  const elec = estimateElectricals(pct, charging);

  percentEl.textContent = String(pct);
  laPercent.textContent = `${pct}%`;
  statusBattery.textContent = String(pct);

  const offset = CIRCUMFERENCE * (1 - level / 100);
  ringProgress.style.strokeDashoffset = String(offset);

  screen.classList.toggle("is-charging", charging);
  liveActivity.hidden = !charging;
  chargeSocket.hidden = !charging;
  meters.hidden = !charging;
  toggle.setAttribute("aria-pressed", charging ? "true" : "false");
  toggle.textContent = charging ? "Unplug charger" : "Connect charger";

  if (!charging) {
    chargeLabel.textContent = "ON BATTERY";
    watts.textContent = "Plug in to wake Aura";
    fastBadge.hidden = true;
    flowers = [];
    flowerCtx.clearRect(0, 0, flowerCanvas.clientWidth, flowerCanvas.clientHeight);
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
    watts.textContent = `Fast charging confirmed · ${elec.w.toFixed(0)} W`;
  } else {
    fastBadge.textContent = elec.mode.toUpperCase();
    fastBadge.classList.add("is-standard");
    watts.textContent =
      pct >= 100
        ? `Holding 100% · ${elec.v.toFixed(1)} V`
        : `${elec.mode} · ${elec.w.toFixed(0)} W`;
  }
}

toggle.addEventListener("click", () => {
  charging = !charging;
  if (charging) spawnFlowers(16);
  render();
});

levelInput.addEventListener("input", () => {
  level = Number(levelInput.value);
  render();
});

setInterval(() => {
  if (!charging || level >= 100) {
    render();
    return;
  }
  level = Math.min(100, level + 0.35);
  levelInput.value = String(Math.round(level));
  render();
}, 1200);

window.addEventListener("resize", () => {
  resizeCanvas();
});

tickClock();
setInterval(tickClock, 30_000);
resizeCanvas();
render();
animId = requestAnimationFrame(flowerLoop);
