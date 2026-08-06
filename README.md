# Aura — Stylish charging lock screen for iPhone 17 Pro Max

When your iPhone is plugged in, **Aura** shows a cinematic charging status — in the app, as a **Lock Screen Live Activity**, and as a **StandBy** face for MagSafe nightstand charging on Pro Max.

## Features

- **Immersive charging canvas** — full-bleed battery ring, charge %, and soft OLED motion when USB-C / MagSafe is connected
- **Random mini scenes from the socket** — flowers, rocket, drone, train, Ferrari, scooter, fish, sparrows, snake, sunrise, popcorn, sea beach (reshuffles every few seconds)
- **Voltage · Current · Power** — live meters while charging, plus a clear **Fast charging confirmed** badge when on the peak USB-PD curve
- **Lock Screen Live Activity** — stylish percentage + V/A while the phone is locked
- **StandBy widget** — landscape charging face for bedside Pro Max use
- Tuned for **iPhone 17 Pro Max** (6.9″ · 2868×1320 · ~440×956 pt)

> Voltage and current use a typical iPhone 17 Pro Max USB-PD estimate curve. Apple does not expose real charger V/A to third-party apps.


## Open in Xcode

1. On a Mac with **Xcode 16+**, open `Aura.xcodeproj`
2. Select the **Aura** scheme → iPhone 17 Pro Max simulator (or any Pro Max)
3. Build & run (`⌘R`)
4. In Simulator: **Features → Battery → Charging** to preview the charging UI

Deployment target: **iOS 17**.

### Enable Lock Screen Live Activity

After first launch, grant Live Activities when prompted (or Settings → Aura → Live Activities). Plug in a charger — Aura starts/updates the lock-screen activity automatically.

> Apple does not allow third-party apps to replace the system lock-screen battery icon. Aura adds a **Live Activity** and in-app / StandBy charging face beside the system UI.

## CUT — browser video editor

Effortless timeline editing in the browser (import, trim, split, titles, looks, export):

```bash
cd video-editor
npm install
npm run dev
```

See [`video-editor/README.md`](video-editor/README.md) for details.

## Preview without Xcode

```bash
cd preview && python3 -m http.server 8080
```

Open the page and toggle **Charging** to see the lock-screen style UI at Pro Max size.

## Project layout

| Path | Purpose |
| --- | --- |
| `Aura/` | Main SwiftUI app + battery monitor |
| `AuraChargeWidget/` | Live Activity + StandBy widget extension |
| `Aura.xcodeproj/` | Xcode project |
| `preview/` | Interactive web mock |
