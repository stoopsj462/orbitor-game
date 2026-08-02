# Orbitor

A one-tap neon arcade game for iPhone, iPad, and Mac. Your glowing ship orbits a
planet on two rings — tap to leap between them, dodge the barriers, and collect
stars as the speed ramps up.

Every pixel is drawn in code (SwiftUI `Canvas` + blur glow, particles, screen shake).
No image assets, no ads, no in-app purchases, no tracking.

## Gameplay
- **Tap** (iOS) or **click / spacebar** (Mac) to jump between the inner and outer orbit.
- Dodge the red barrier arcs; grab the gold stars.
- Speed increases with your score. One more run.

## Progression
- **9 orb colors** unlocked by best score (skill-gated, `0 → 900`).
- **Star Shop** — spend collected stars on 5 trail styles and 5 planet themes.
- Best score, star balance, and cosmetics persist locally.

## Project layout
| File | Role |
|---|---|
| `vibe game/vibe game/GameModel.swift` | State + physics engine |
| `vibe game/vibe game/GameView.swift` | Canvas rendering, input, HUD, overlays |
| `vibe game/vibe game/ShopView.swift` | The Star Shop |
| `vibe game/vibe game/Assets.xcassets/AppIcon.appiconset` | App icon (generated in code) |
| `docs/` | GitHub Pages site: landing page + privacy policy |
| `store/` | App Store listing copy |

## Requirements
- Xcode (iOS 27 / macOS 27 SDK)
- Universal target: iPhone, iPad, Mac

## Hosting the privacy policy (GitHub Pages)
1. Push this repo to GitHub (name it `orbitor`).
2. In the repo: **Settings → Pages → Build and deployment**.
3. Source: **Deploy from a branch**, Branch: **main**, Folder: **/docs**. Save.
4. After a minute your pages are live at:
   - Landing: `https://<your-username>.github.io/orbitor/`
   - Privacy: `https://<your-username>.github.io/orbitor/privacy.html`
5. Use the privacy URL in App Store Connect.

## License
© 2026 Jason Stoops. All rights reserved.
