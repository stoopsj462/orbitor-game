//
//  GameView.swift
//  vibe game
//
//  ORBIT — rendering, input and overlays. Everything is drawn in code
//  with a SwiftUI Canvas; no image assets are used.
//

import SwiftUI
import QuartzCore

struct GameView: View {
    @State private var model = GameModel()
    @State private var showShop = false

    // Palette
    private let spaceTop = Color(red: 0.04, green: 0.05, blue: 0.11)
    private let spaceBottom = Color(red: 0.01, green: 0.01, blue: 0.03)
    private let cyan = Color(red: 0.30, green: 0.85, blue: 1.0)
    private let danger = Color(red: 1.0, green: 0.28, blue: 0.42)
    private let gold = Color(red: 1.0, green: 0.82, blue: 0.28)

    /// The player's currently equipped orb color.
    private var skin: Color { model.shipColor }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [spaceTop, spaceBottom],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                .ignoresSafeArea()

                overlay

                if showShop {
                    ShopView(model: model, isPresented: $showShop)
                }
            }
            .onAppear { model.size = geo.size }
            .onChange(of: geo.size) { _, newValue in model.size = newValue }
        }
        .background(spaceBottom.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { if !showShop { model.handleTap() } }
        .focusable()
        .onKeyPress(.space) { guard !showShop else { return .ignored }; model.handleTap(); return .handled }
        .onKeyPress(.return) { guard !showShop else { return .ignored }; model.handleTap(); return .handled }
        .onKeyPress(KeyEquivalent("s")) {
            guard !showShop, model.phase != .playing else { return .ignored }
            showShop = true
            return .handled
        }
        .onKeyPress(.escape) {
            guard showShop else { return .ignored }
            showShop = false
            return .handled
        }
        .task {
            applyLaunchStateForScreenshots()
            await runLoop()
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 640)
        #endif
    }

    // MARK: Game loop

    /// DEBUG-only hook to place the game into a specific state for capturing marketing
    /// screenshots, e.g. `Orbitor -uiState shop`. Has no effect in release builds or normal launches.
    private func applyLaunchStateForScreenshots() {
        #if DEBUG
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-uiState"), i + 1 < args.count else { return }
        // Seed some progress so shop/menu look populated.
        model.best = 250
        model.starBalance = 140
        switch args[i + 1] {
        case "shop": showShop = true
        case "play":
            model.screenshotMode = true
            model.startRun()
        default: break
        }
        #endif
    }

    private func runLoop() async {
        var last = CACurrentMediaTime()
        while !Task.isCancelled {
            let now = CACurrentMediaTime()
            model.update(dt: now - last)
            last = now
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0 else { return }

        // Screen shake.
        if model.shake > 0 {
            let amp = model.shake * 12
            context.translateBy(x: .random(in: -amp...amp), y: .random(in: -amp...amp))
        }

        drawBackgroundStars(context, size: size)
        drawRings(context)
        drawPlanet(context)
        drawEntities(context)
        drawShip(context)
        drawParticles(context)
    }

    private func glow(_ context: GraphicsContext, at p: CGPoint, radius: Double,
                      color: Color, blur: Double, opacity: Double = 1) {
        context.drawLayer { layer in
            layer.opacity = opacity
            layer.addFilter(.blur(radius: blur))
            let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            layer.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func drawBackgroundStars(_ context: GraphicsContext, size: CGSize) {
        let center = model.center
        let drift = model.time * 0.02 + model.distance * 0.04
        for star in model.backgroundStars {
            let a = star.angle + drift
            let p = CGPoint(x: center.x + cos(a) * star.radius,
                            y: center.y + sin(a) * star.radius)
            let twinkle = 0.6 + 0.4 * sin(model.time * 2 + star.angle * 5)
            let rect = CGRect(x: p.x, y: p.y, width: star.size, height: star.size)
            context.fill(Path(ellipseIn: rect),
                         with: .color(.white.opacity(star.alpha * twinkle)))
        }
    }

    private func drawRings(_ context: GraphicsContext) {
        let center = model.center
        for ring in 0...1 {
            let r = model.ringRadius(ring)
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.stroke(Path(ellipseIn: rect),
                           with: .color(.white.opacity(0.07)),
                           lineWidth: 2)
        }
    }

    private func drawPlanet(_ context: GraphicsContext) {
        let center = model.center
        let theme = model.activePlanet
        let base = model.minDimension * 0.15
        let pulse = base * (1 + 0.04 * sin(model.time * 1.6))

        glow(context, at: center, radius: pulse * 1.9, color: theme.glow, blur: 40, opacity: 0.35)

        let rect = CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2)
        let gradient = Gradient(colors: [theme.inner, theme.mid, theme.outer])
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(gradient,
                                  center: CGPoint(x: center.x - pulse * 0.3, y: center.y - pulse * 0.3),
                                  startRadius: 0, endRadius: pulse * 1.3)
        )
    }

    private func drawEntities(_ context: GraphicsContext) {
        let center = model.center
        for entity in model.entities where !(entity.kind == .star && entity.collected) {
            let angle = model.screenAngle(for: entity)
            // Only draw entities within the visible arc in front of the ship.
            let delta = entity.distance - model.distance
            guard delta > -0.4, delta < 3.4 else { continue }

            let radius = model.ringRadius(entity.ring)
            let fade = min(1, max(0.15, (3.4 - delta) / 3.4))

            switch entity.kind {
            case .obstacle:
                drawObstacle(context, center: center, radius: radius, angle: angle, fade: fade)
            case .star:
                let p = model.pointOnRing(angle: angle, radius: radius)
                drawStar(context, at: p, fade: fade)
            }
        }
    }

    private func drawObstacle(_ context: GraphicsContext, center: CGPoint,
                              radius: Double, angle: Double, fade: Double) {
        let half = 0.16
        var path = Path()
        path.addArc(center: center, radius: radius,
                    startAngle: .radians(angle - half),
                    endAngle: .radians(angle + half),
                    clockwise: false)

        let mid = model.pointOnRing(angle: angle, radius: radius)
        glow(context, at: mid, radius: 16, color: danger, blur: 14, opacity: 0.7 * fade)
        context.stroke(path,
                       with: .color(danger.opacity(fade)),
                       style: StrokeStyle(lineWidth: 15, lineCap: .round))
        context.stroke(path,
                       with: .color(.white.opacity(0.5 * fade)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }

    private func drawStar(_ context: GraphicsContext, at p: CGPoint, fade: Double) {
        glow(context, at: p, radius: 12, color: gold, blur: 12, opacity: 0.8 * fade)
        let s = 7.0
        var diamond = Path()
        diamond.move(to: CGPoint(x: p.x, y: p.y - s))
        diamond.addLine(to: CGPoint(x: p.x + s, y: p.y))
        diamond.addLine(to: CGPoint(x: p.x, y: p.y + s))
        diamond.addLine(to: CGPoint(x: p.x - s, y: p.y))
        diamond.closeSubpath()
        context.fill(diamond, with: .color(gold.opacity(fade)))
        context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)),
                     with: .color(.white.opacity(fade)))
    }

    private func drawShip(_ context: GraphicsContext) {
        let p = model.shipPosition
        drawTrail(context, at: p, radius: model.shipRadius)

        glow(context, at: p, radius: 20, color: skin, blur: 16)
        context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)),
                     with: .color(skin))
        context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)),
                     with: .color(.white))
    }

    /// Renders the equipped trail style trailing behind the ship along its ring.
    private func drawTrail(_ context: GraphicsContext, at p: CGPoint, radius: Double) {
        let a0 = model.shipScreenAngle
        let sweep = 0.55
        let endPoint = model.pointOnRing(angle: a0 + sweep, radius: radius)

        func arc(offset: Double = 0) -> Path {
            var path = Path()
            path.addArc(center: model.center, radius: radius + offset,
                        startAngle: .radians(a0), endAngle: .radians(a0 + sweep),
                        clockwise: false)
            return path
        }

        switch model.selectedTrailID {
        case "sparkle":
            let samples = 7
            for i in 1...samples {
                let t = Double(i) / Double(samples)
                let pos = model.pointOnRing(angle: a0 + sweep * t, radius: radius)
                let s = (1 - t) * 4 + 1
                context.fill(Path(ellipseIn: CGRect(x: pos.x - s, y: pos.y - s, width: s * 2, height: s * 2)),
                             with: .color(skin.opacity((1 - t) * 0.85)))
            }
        case "ribbon":
            for off in [-4.0, 4.0] {
                context.stroke(arc(offset: off),
                               with: .linearGradient(Gradient(colors: [skin.opacity(0.6), .clear]),
                                                     startPoint: p, endPoint: endPoint),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        case "pulse":
            for i in 0..<3 {
                let phase = (model.time * 1.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let rr = 10 + phase * 22
                context.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                               with: .color(skin.opacity((1 - phase) * 0.5)), lineWidth: 2)
            }
        case "rainbow":
            let hues = (0..<6).map { i in
                Color(hue: (model.time * 0.2 + Double(i) / 6).truncatingRemainder(dividingBy: 1),
                      saturation: 0.9, brightness: 1)
            }
            context.stroke(arc(),
                           with: .linearGradient(Gradient(colors: hues + [.clear]),
                                                 startPoint: p, endPoint: endPoint),
                           style: StrokeStyle(lineWidth: 7, lineCap: .round))
        default: // comet
            context.stroke(arc(),
                           with: .linearGradient(Gradient(colors: [skin.opacity(0.55), .clear]),
                                                 startPoint: p, endPoint: endPoint),
                           style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
    }

    private func drawParticles(_ context: GraphicsContext) {
        for particle in model.particles {
            let alpha = max(0, particle.life / particle.maxLife)
            let s = particle.size
            let rect = CGRect(x: particle.pos.x - s, y: particle.pos.y - s, width: s * 2, height: s * 2)
            context.fill(Path(ellipseIn: rect), with: .color(particle.color.opacity(alpha)))
        }
    }

    // MARK: Overlays

    @ViewBuilder
    private var overlay: some View {
        switch model.phase {
        case .playing:
            hud
        case .menu:
            menu
        case .gameOver:
            gameOverPanel
        }
    }

    private var hud: some View {
        VStack {
            HStack(alignment: .top) {
                Label("\(model.stars)", systemImage: "star.fill")
                    .foregroundStyle(gold)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Text("BEST \(model.best)")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            Text("\(model.score)")
                .foregroundStyle(.white)
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .shadow(color: skin.opacity(0.75), radius: 12)
            Spacer()
        }
        .padding(24)
        .allowsHitTesting(false)
    }

    /// A subtle dark card that keeps overlay text readable over the bright planet on any screen size.
    private var panelScrim: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(spaceBottom.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
            .allowsHitTesting(false)
    }

    private var menu: some View {
        VStack(spacing: 16) {
            Text("ORBITOR")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(skin)
                .shadow(color: skin.opacity(0.8), radius: 18)
                .allowsHitTesting(false)
            Text("Tap to leap between rings.\nDodge the barriers. Grab the stars.")
                .multilineTextAlignment(.center)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .allowsHitTesting(false)
            if model.best > 0 {
                Text("BEST  \(model.best)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(gold)
                    .allowsHitTesting(false)
            }

            skinSection
                .padding(.top, 6)

            shopButton
                .padding(.top, 2)

            pill("TAP TO START")
                .padding(.top, 6)
                .allowsHitTesting(false)
        }
        .padding(32)
        .background(panelScrim)
        .padding(24)
    }

    private var gameOverPanel: some View {
        VStack(spacing: 14) {
            Text(model.score >= model.best && model.score > 0 ? "NEW BEST!" : "GAME OVER")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(model.score >= model.best && model.score > 0 ? gold : danger)
                .shadow(color: (model.score >= model.best ? gold : danger).opacity(0.7), radius: 12)
                .allowsHitTesting(false)

            HStack(spacing: 28) {
                stat(title: "SCORE", value: "\(model.score)", color: .white)
                stat(title: "STARS", value: "+\(model.stars)", color: gold)
                stat(title: "BEST", value: "\(model.best)", color: cyan)
            }
            .allowsHitTesting(false)

            if let unlock = model.newlyUnlocked {
                banner(icon: "sparkles", text: "New color unlocked: \(unlock.name)!", color: unlock.color)
            }

            skinSection
                .padding(.top, 4)

            shopButton
                .padding(.top, 2)

            pill("TAP TO RETRY")
                .padding(.top, 6)
                .allowsHitTesting(false)
        }
        .padding(32)
        .background(panelScrim)
        .padding(24)
    }

    private func banner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(color.opacity(0.16)))
        .allowsHitTesting(false)
    }

    // MARK: Shop entry

    private var shopButton: some View {
        Button { showShop = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "bag.fill")
                Text("SHOP")
                Text("·")
                Image(systemName: "star.fill").font(.system(size: 12))
                Text("\(model.starBalance)")
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(.white.opacity(0.12)))
            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Skin picker

    private var skinSection: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(GameModel.skins) { skin in
                        skinDot(skin)
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(maxWidth: 360)

            Text(unlockCaption)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .allowsHitTesting(false)
        }
    }

    private var unlockCaption: String {
        if let next = model.nextLockedSkin {
            return "\(model.activeSkin.name) equipped · unlock “\(next.name)” at \(next.unlockScore)"
        }
        return "\(model.activeSkin.name) equipped · all \(GameModel.skins.count) colors unlocked ✦"
    }

    private func skinDot(_ skin: OrbitSkin) -> some View {
        let unlocked = model.isUnlocked(skin)
        let selected = model.selectedSkinIndex == skin.id
        return Button {
            model.selectSkin(skin.id)
        } label: {
            ZStack {
                Circle()
                    .fill(unlocked ? skin.color : Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(.white.opacity(selected ? 0.95 : 0.18),
                                        lineWidth: selected ? 3 : 1)
                    )
                    .shadow(color: unlocked ? skin.color.opacity(0.7) : .clear,
                            radius: selected ? 9 : 3)
                if !unlocked {
                    VStack(spacing: 0) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(skin.unlockScore)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    private func stat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .background(Capsule().fill(skin))
            .shadow(color: skin.opacity(0.6), radius: 14)
            .opacity(0.75 + 0.25 * sin(model.time * 3))
    }
}

#Preview {
    GameView()
}
