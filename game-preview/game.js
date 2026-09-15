(() => {
  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const menu = document.getElementById("menu");
  const gameover = document.getElementById("gameover");
  const hud = document.getElementById("hud");
  const scoreEl = document.getElementById("score");
  const hudBest = document.getElementById("hudBest");
  const menuBest = document.getElementById("menuBest");
  const finalScore = document.getElementById("finalScore");
  const bestNote = document.getElementById("bestNote");

  const W = canvas.width;
  const H = canvas.height;
  const LANES = 3;
  const PLAYER_Y = 0.82;
  const STORAGE_KEY = "sparklane.highScore";

  let phase = "menu";
  let lane = 1;
  let score = 0;
  let highScore = Number(localStorage.getItem(STORAGE_KEY) || 0);
  let entities = [];
  let bursts = [];
  let speed = 220;
  let spawnCooldown = 0.4;
  let distanceAcc = 0;
  let last = 0;
  let shake = 0;
  let raf = 0;

  function laneX(i) {
    return W * ((i + 1) / (LANES + 1));
  }

  function refreshBestUI() {
    hudBest.textContent = `BEST ${highScore}`;
    if (highScore > 0) {
      menuBest.hidden = false;
      menuBest.querySelector("span").textContent = String(highScore);
    } else {
      menuBest.hidden = true;
    }
  }

  function setPhase(next) {
    phase = next;
    menu.hidden = next !== "menu";
    gameover.hidden = next !== "gameOver";
    hud.hidden = next === "menu";
  }

  function start() {
    lane = 1;
    score = 0;
    entities = [];
    bursts = [];
    speed = 220;
    spawnCooldown = 0.4;
    distanceAcc = 0;
    shake = 0;
    last = performance.now();
    scoreEl.textContent = "0";
    setPhase("playing");
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(loop);
  }

  function endRun() {
    setPhase("gameOver");
    shake = 1;
    finalScore.textContent = String(score);
    if (score > highScore) {
      highScore = score;
      localStorage.setItem(STORAGE_KEY, String(highScore));
      bestNote.textContent = "New best charge";
    } else {
      bestNote.textContent = `Best  ${highScore}`;
    }
    refreshBestUI();
  }

  function spawn() {
    const pick = Math.floor(Math.random() * LANES);
    const kind = Math.random() < 0.62 ? "hazard" : "orb";
    entities.push({ id: Math.random(), lane: pick, y: -0.08, kind });
    if (speed > 300 && Math.random() < 0.35) {
      const others = [0, 1, 2].filter((n) => n !== pick);
      const other = others[Math.floor(Math.random() * others.length)];
      entities.push({ id: Math.random(), lane: other, y: -0.18, kind: "hazard" });
    }
  }

  function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000 || 1 / 60);
    last = now;

    if (phase === "playing") {
      speed = Math.min(480, speed + dt * 8);
      spawnCooldown -= dt;
      if (spawnCooldown <= 0) {
        spawn();
        const base = Math.max(0.28, 0.85 - (speed - 220) / 500);
        spawnCooldown = base + Math.random() * 0.18;
      }

      distanceAcc += dt * speed * 0.02;
      if (distanceAcc >= 1) {
        const add = Math.floor(distanceAcc);
        score += add;
        distanceAcc -= add;
        scoreEl.textContent = String(score);
      }

      const next = [];
      for (const e of entities) {
        e.y += (speed * dt) / 900;
        if (e.y > 1.15) continue;
        const near = Math.abs(e.y - PLAYER_Y) < 0.045 && e.lane === lane;
        if (near) {
          if (e.kind === "orb") {
            score += 10;
            scoreEl.textContent = String(score);
            bursts.push({ x: laneX(e.lane), y: e.y * H, born: now });
            continue;
          }
          endRun();
          break;
        }
        next.push(e);
      }
      if (phase === "playing") entities = next;
      bursts = bursts.filter((b) => now - b.born < 450);
      if (shake > 0) shake = Math.max(0, shake - dt * 8);
    }

    draw(now);
    raf = requestAnimationFrame(loop);
  }

  function draw(now) {
    const ox = shake > 0 ? (Math.random() * 12 - 6) * shake : 0;
    ctx.save();
    ctx.translate(ox, 0);

    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, "#143042");
    g.addColorStop(0.45, "#0a1723");
    g.addColorStop(1, "#0c1f28");
    ctx.fillStyle = g;
    ctx.fillRect(-10, 0, W + 20, H);

    // horizon glow
    const hg = ctx.createRadialGradient(W / 2, H * 0.15, 10, W / 2, H * 0.15, W * 0.7);
    hg.addColorStop(0, "rgba(46,184,173,0.22)");
    hg.addColorStop(1, "rgba(46,184,173,0)");
    ctx.fillStyle = hg;
    ctx.fillRect(0, 0, W, H * 0.5);

    // lanes
    for (let i = 0; i < LANES; i++) {
      const x = laneX(i);
      ctx.beginPath();
      roundRect(ctx, x - W * 0.11, H * 0.08, W * 0.22, H * 0.78, 40);
      ctx.fillStyle = i === lane ? "rgba(184,240,230,0.14)" : "rgba(184,240,230,0.05)";
      ctx.fill();
    }

    // entities
    for (const e of entities) {
      const x = laneX(e.lane);
      const y = e.y * H;
      if (e.kind === "orb") {
        ctx.beginPath();
        ctx.arc(x, y, 18, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(46,184,173,0.3)";
        ctx.fill();
        const og = ctx.createRadialGradient(x - 4, y - 4, 1, x, y, 14);
        og.addColorStop(0, "#b8f0e6");
        og.addColorStop(1, "#2eb8ad");
        ctx.beginPath();
        ctx.arc(x, y, 14, 0, Math.PI * 2);
        ctx.fillStyle = og;
        ctx.fill();
      } else {
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(0.2);
        roundRect(ctx, -20, -20, 40, 40, 10);
        ctx.fillStyle = "#516175";
        ctx.fill();
        ctx.strokeStyle = "rgba(255,255,255,0.12)";
        ctx.lineWidth = 1;
        ctx.stroke();
        ctx.restore();
      }
    }

    // bursts
    for (const b of bursts) {
      const t = (now - b.born) / 450;
      for (let i = 0; i < 6; i++) {
        const a = (i * Math.PI) / 3;
        const r = 8 + t * 28;
        ctx.beginPath();
        ctx.arc(b.x + Math.cos(a) * r, b.y + Math.sin(a) * r, 4, 0, Math.PI * 2);
        ctx.fillStyle = i % 2 ? `rgba(46,184,173,${1 - t})` : `rgba(255,184,71,${1 - t})`;
        ctx.fill();
      }
    }

    // player
    const px = laneX(lane);
    const py = PLAYER_Y * H;
    const pg = ctx.createRadialGradient(px, py, 2, px, py, 36);
    pg.addColorStop(0, "rgba(255,184,71,0.9)");
    pg.addColorStop(0.5, "rgba(255,107,71,0.55)");
    pg.addColorStop(1, "rgba(255,107,71,0)");
    ctx.beginPath();
    ctx.arc(px, py, 36, 0, Math.PI * 2);
    ctx.fillStyle = pg;
    ctx.fill();

    const core = ctx.createRadialGradient(px - 4, py - 4, 1, px, py, 20);
    core.addColorStop(0, "#ffffff");
    core.addColorStop(0.4, "#ffb847");
    core.addColorStop(1, "#ff6b47");
    ctx.beginPath();
    ctx.arc(px, py, 20, 0, Math.PI * 2);
    ctx.fillStyle = core;
    ctx.fill();

    ctx.beginPath();
    ctx.arc(px, py, 26, 0, Math.PI * 2);
    ctx.strokeStyle = "rgba(184,240,230,0.35)";
    ctx.lineWidth = 2;
    ctx.stroke();

    // ground glow
    const gg = ctx.createRadialGradient(W / 2, H * 0.92, 10, W / 2, H * 0.92, W * 0.5);
    gg.addColorStop(0, "rgba(255,107,71,0.12)");
    gg.addColorStop(1, "rgba(255,107,71,0)");
    ctx.fillStyle = gg;
    ctx.fillRect(0, H * 0.7, W, H * 0.3);

    ctx.restore();
  }

  function roundRect(c, x, y, w, h, r) {
    c.moveTo(x + r, y);
    c.arcTo(x + w, y, x + w, y + h, r);
    c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r);
    c.arcTo(x, y, x + w, y, r);
    c.closePath();
  }

  function onTap(clientX, rect) {
    if (phase !== "playing") return;
    const mid = rect.left + rect.width / 2;
    if (clientX < mid) lane = Math.max(0, lane - 1);
    else lane = Math.min(LANES - 1, lane + 1);
  }

  canvas.addEventListener("pointerdown", (e) => {
    const rect = canvas.getBoundingClientRect();
    onTap(e.clientX, rect);
  });

  document.getElementById("playBtn").addEventListener("click", start);
  document.getElementById("againBtn").addEventListener("click", start);
  document.getElementById("menuBtn").addEventListener("click", () => {
    setPhase("menu");
    refreshBestUI();
  });

  window.addEventListener("keydown", (e) => {
    if (phase !== "playing") {
      if (e.key === " " || e.key === "Enter") start();
      return;
    }
    if (e.key === "ArrowLeft" || e.key === "a") lane = Math.max(0, lane - 1);
    if (e.key === "ArrowRight" || e.key === "d") lane = Math.min(LANES - 1, lane + 1);
  });

  refreshBestUI();
  setPhase("menu");
  last = performance.now();
  raf = requestAnimationFrame(loop);
})();
