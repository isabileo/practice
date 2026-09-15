# Sparklane — iOS arcade game

**Sparklane** is a SwiftUI endless lane game for iPhone: dodge void stones, collect charge orbs, and chase a high score.

## How to play

- **Tap left / right** half of the screen to switch between 3 lanes
- **Collect** teal charge orbs (+10)
- **Avoid** gray void stones — one hit ends the run
- Speed ramps up the longer you survive

## Open in Xcode

1. On a Mac with **Xcode 16+**, open `Sparklane.xcodeproj`
2. Select the **Sparklane** scheme → any iPhone simulator
3. Build & run (`⌘R`)

Deployment target: **iOS 17**.

## Preview in the browser

```bash
cd game-preview && python3 -m http.server 8080
```

Open the page, tap **PLAY**, then tap left/right (or use ← → / A D).

## Project layout

| Path | Purpose |
| --- | --- |
| `Sparklane/` | SwiftUI game app (engine, views, theme) |
| `Sparklane.xcodeproj/` | Xcode project |
| `game-preview/` | Playable HTML/Canvas preview |
| `Aura/` | Separate charging lock-screen app (unchanged) |
