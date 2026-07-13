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

const CIRCUMFERENCE = 2 * Math.PI * 86;

ringProgress.style.strokeDasharray = String(CIRCUMFERENCE);

let charging = false;
let level = Number(levelInput.value);

function tickClock() {
  const now = new Date();
  clock.textContent = now.toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
}

function render() {
  const pct = Math.round(level);
  percentEl.textContent = String(pct);
  laPercent.textContent = `${pct}%`;
  statusBattery.textContent = String(pct);

  const offset = CIRCUMFERENCE * (1 - level / 100);
  ringProgress.style.strokeDashoffset = String(offset);

  screen.classList.toggle("is-charging", charging);
  liveActivity.hidden = !charging;
  toggle.setAttribute("aria-pressed", charging ? "true" : "false");
  toggle.textContent = charging ? "Unplug charger" : "Connect charger";

  if (!charging) {
    chargeLabel.textContent = "ON BATTERY";
    watts.textContent = "Plug in to wake Aura";
    return;
  }

  if (pct >= 100) {
    chargeLabel.textContent = "FULLY CHARGED";
    watts.textContent = "Holding 100%";
  } else if (pct >= 80) {
    chargeLabel.textContent = "CHARGING";
    watts.textContent = "Trickle · finishing up";
  } else {
    chargeLabel.textContent = "CHARGING";
    watts.textContent = "Fast charge · up to 40W";
  }
}

toggle.addEventListener("click", () => {
  charging = !charging;
  render();
});

levelInput.addEventListener("input", () => {
  level = Number(levelInput.value);
  render();
});

// Demo auto-fill while "charging"
setInterval(() => {
  if (!charging || level >= 100) return;
  level = Math.min(100, level + 0.4);
  levelInput.value = String(Math.round(level));
  render();
}, 1200);

tickClock();
setInterval(tickClock, 30_000);
render();
