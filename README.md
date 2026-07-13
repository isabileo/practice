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

## Open on iPhone (no Mac)

Safari on your iPhone → open this link (single file, works offline once loaded):

**https://cdn.jsdelivr.net/gh/isabileo/practice@cursor/iphone-17-pro-max-app-7ed1/preview/open-on-iphone.html**

Backup link:

**https://raw.githack.com/isabileo/practice/cursor/iphone-17-pro-max-app-7ed1/preview/open-on-iphone.html**

Then tap **Connect charger**. Optional: Share → **Add to Home Screen**.

> Do not use the GitHub “Code” file page — that only shows source text and will not run the app.

### Local preview (computer)

```bash
cd preview && python3 -m http.server 8080
```

## Project layout

| Path | Purpose |
| --- | --- |
| `Aura/` | Main SwiftUI app + battery monitor |
| `AuraChargeWidget/` | Live Activity + StandBy widget extension |
| `Aura.xcodeproj/` | Xcode project |
| `preview/` | Interactive web mock |
