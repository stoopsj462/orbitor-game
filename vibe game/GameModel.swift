//
//  GameModel.swift
//  vibe game
//
//  ORBIT — one-tap arcade game engine.
//  Pure state + physics. All rendering lives in GameView.
//

import SwiftUI
import QuartzCore

#if os(iOS)
import UIKit
#endif

/// The three high-level states the game can be in.
enum GamePhase {
    case menu
    case playing
    case gameOver
}

/// Category of a purchasable cosmetic.
enum CosmeticKind {
    case trail
    case planet
}

/// Every knob that defines how a difficulty level plays.
struct DifficultyTuning {
    let baseSpeed: Double       // travel speed at score 0, radians/second
    let maxSpeed: Double        // ceiling the ramp never exceeds
    let speedRamp: Double       // speed gained per point of score
    let startSlotGap: Double    // radians between spawn slots at score 0
    let minSlotGap: Double      // tightest the slots ever get
    let gapTighten: Double      // gap removed per point of score
    let safeStarChance: Double  // odds a star appears on the safe ring
    let runway: Double          // safe distance before the very first barrier
}

/// The four selectable levels of play. Each owns its full tuning curve and its own
/// persisted best score, so a gentle run on Easy never overwrites an Extreme record.
enum Difficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard, extreme

    var id: String { rawValue }

    var name: String {
        switch self {
        case .easy:    return "EASY"
        case .normal:  return "NORMAL"
        case .hard:    return "HARD"
        case .extreme: return "EXTREME"
        }
    }

    /// Accent color for the picker pills and the in-run HUD badge.
    var tint: Color {
        switch self {
        case .easy:    return Color(red: 0.42, green: 1.00, blue: 0.55)
        case .normal:  return Color(red: 0.30, green: 0.85, blue: 1.00)
        case .hard:    return Color(red: 1.00, green: 0.55, blue: 0.20)
        case .extreme: return Color(red: 1.00, green: 0.26, blue: 0.40)
        }
    }

    /// Game Center leaderboard for this level's best scores. Must match a
    /// leaderboard ID configured for this app in App Store Connect.
    var leaderboardID: String {
        "com.jasonstoops.orbitor.leaderboard.\(rawValue)"
    }

    /// Normal reproduces the original single-difficulty curve exactly.
    var tuning: DifficultyTuning {
        switch self {
        case .easy:
            return DifficultyTuning(baseSpeed: 1.30, maxSpeed: 3.00, speedRamp: 0.016,
                                    startSlotGap: 1.32, minSlotGap: 0.90, gapTighten: 0.004,
                                    safeStarChance: 0.88, runway: 3.6)
        case .normal:
            return DifficultyTuning(baseSpeed: 1.70, maxSpeed: 4.40, speedRamp: 0.030,
                                    startSlotGap: 1.08, minSlotGap: 0.62, gapTighten: 0.006,
                                    safeStarChance: 0.72, runway: 2.6)
        case .hard:
            return DifficultyTuning(baseSpeed: 2.05, maxSpeed: 5.20, speedRamp: 0.040,
                                    startSlotGap: 0.98, minSlotGap: 0.56, gapTighten: 0.008,
                                    safeStarChance: 0.62, runway: 2.2)
        case .extreme:
            return DifficultyTuning(baseSpeed: 2.40, maxSpeed: 6.00, speedRamp: 0.052,
                                    startSlotGap: 0.90, minSlotGap: 0.48, gapTighten: 0.010,
                                    safeStarChance: 0.52, runway: 1.9)
        }
    }
}

/// Something living on the orbit track: either a barrier to dodge or a star to collect.
struct TrackEntity: Identifiable {
    enum Kind { case obstacle, star }

    let id = UUID()
    var distance: Double   // position along the track, in radians of travel
    var ring: Int          // 0 = inner ring, 1 = outer ring
    var kind: Kind
    var collected = false  // star already grabbed
    var scored = false     // obstacle already counted as "survived"
}

/// A short-lived visual spark used for collect / crash bursts.
struct Particle: Identifiable {
    let id = UUID()
    var pos: CGPoint
    var vel: CGVector
    var life: Double
    var maxLife: Double
    var color: Color
    var size: Double
}

/// A faint background star for the parallax field.
struct BackgroundStar {
    var angle: Double
    var radius: Double
    var size: Double
    var alpha: Double
}

/// A selectable ship color the player unlocks by reaching a best-score threshold.
struct OrbitSkin: Identifiable {
    let id: Int
    let name: String
    let color: Color
    let unlockScore: Int
}

/// A ship trail effect bought with stars.
struct TrailStyle: Identifiable {
    let id: String
    let name: String
    let cost: Int
}

/// A central-planet look bought with stars.
struct PlanetTheme: Identifiable {
    let id: String
    let name: String
    let cost: Int
    let inner: Color
    let mid: Color
    let outer: Color
    let glow: Color
}

@Observable
final class GameModel {

    // MARK: Catalogs

    /// Orb colors. Skill-gated: unlocked by best score, with a widening late-game curve.
    static let skins: [OrbitSkin] = [
        OrbitSkin(id: 0, name: "Aurora",   color: Color(red: 0.30, green: 0.85, blue: 1.00), unlockScore: 0),
        OrbitSkin(id: 1, name: "Solar",    color: Color(red: 1.00, green: 0.82, blue: 0.28), unlockScore: 50),
        OrbitSkin(id: 2, name: "Nova",     color: Color(red: 1.00, green: 0.35, blue: 0.66), unlockScore: 100),
        OrbitSkin(id: 3, name: "Venom",    color: Color(red: 0.42, green: 1.00, blue: 0.55), unlockScore: 150),
        OrbitSkin(id: 4, name: "Ember",    color: Color(red: 1.00, green: 0.52, blue: 0.20), unlockScore: 200),
        OrbitSkin(id: 5, name: "Amethyst", color: Color(red: 0.70, green: 0.45, blue: 1.00), unlockScore: 300),
        OrbitSkin(id: 6, name: "Crimson",  color: Color(red: 1.00, green: 0.24, blue: 0.32), unlockScore: 450),
        OrbitSkin(id: 7, name: "Frost",    color: Color(red: 0.86, green: 0.96, blue: 1.00), unlockScore: 650),
        OrbitSkin(id: 8, name: "Void",     color: Color(red: 0.58, green: 0.62, blue: 0.78), unlockScore: 900),
    ]

    /// Ship trails. Grind-gated: bought with banked stars.
    static let trails: [TrailStyle] = [
        TrailStyle(id: "comet",   name: "Comet",   cost: 0),
        TrailStyle(id: "sparkle", name: "Sparkle", cost: 20),
        TrailStyle(id: "ribbon",  name: "Ribbon",  cost: 40),
        TrailStyle(id: "pulse",   name: "Pulse",   cost: 70),
        TrailStyle(id: "rainbow", name: "Rainbow", cost: 120),
    ]

    /// Planet themes. Grind-gated: bought with banked stars.
    static let planets: [PlanetTheme] = [
        PlanetTheme(id: "blue", name: "Azure", cost: 0,
                    inner: Color(red: 0.45, green: 0.95, blue: 1.00),
                    mid:   Color(red: 0.12, green: 0.45, blue: 0.85),
                    outer: Color(red: 0.05, green: 0.15, blue: 0.40),
                    glow:  Color(red: 0.30, green: 0.85, blue: 1.00)),
        PlanetTheme(id: "ember", name: "Ember", cost: 30,
                    inner: Color(red: 1.00, green: 0.85, blue: 0.45),
                    mid:   Color(red: 0.90, green: 0.35, blue: 0.15),
                    outer: Color(red: 0.30, green: 0.08, blue: 0.05),
                    glow:  Color(red: 1.00, green: 0.50, blue: 0.20)),
        PlanetTheme(id: "verdant", name: "Verdant", cost: 30,
                    inner: Color(red: 0.65, green: 1.00, blue: 0.70),
                    mid:   Color(red: 0.20, green: 0.65, blue: 0.35),
                    outer: Color(red: 0.03, green: 0.20, blue: 0.12),
                    glow:  Color(red: 0.35, green: 0.95, blue: 0.55)),
        PlanetTheme(id: "violet", name: "Violet", cost: 60,
                    inner: Color(red: 0.85, green: 0.70, blue: 1.00),
                    mid:   Color(red: 0.50, green: 0.25, blue: 0.85),
                    outer: Color(red: 0.15, green: 0.05, blue: 0.30),
                    glow:  Color(red: 0.70, green: 0.45, blue: 1.00)),
        PlanetTheme(id: "mono", name: "Mono", cost: 100,
                    inner: Color(red: 1.00, green: 1.00, blue: 1.00),
                    mid:   Color(red: 0.55, green: 0.58, blue: 0.65),
                    outer: Color(red: 0.10, green: 0.11, blue: 0.14),
                    glow:  Color(red: 0.85, green: 0.90, blue: 1.00)),
    ]

    // MARK: Tunables

    /// Angle on screen where the ship sits (top / 12 o'clock).
    let shipScreenAngle: Double = -.pi / 2
    /// How close (in radians) an entity must be to the ship to count as a hit / pickup.
    let hitWindow: Double = 0.13

    /// Tuning for the level currently selected.
    private var tuning: DifficultyTuning { difficulty.tuning }

    // MARK: World state

    var phase: GamePhase = .menu
    var size: CGSize = .zero
    var time: Double = 0          // ever-increasing clock for idle animations

    var distance: Double = 0      // how far we've traveled along the track
    var speed: Double = 1.7
    var entities: [TrackEntity] = []
    var particles: [Particle] = []
    var backgroundStars: [BackgroundStar] = []

    /// Committed logical ring (0 or 1). Collisions use this immediately on tap.
    var shipRing = 0
    /// Smoothly-animated ring position the view renders (0.0 ... 1.0).
    var shipLaneValue: Double = 0

    var shake: Double = 0

    // MARK: Scoring, currency & unlocks

    var score = 0
    var stars = 0                 // stars collected this run
    var starBalance = 0           // lifetime banked stars available to spend

    /// The level of play. Persisted so the player's choice survives relaunch.
    var difficulty: Difficulty = .normal
    /// Best score per level, so each difficulty keeps its own record.
    var bests: [Difficulty: Int] = [:]
    /// Best on the level currently selected.
    var best: Int { bests[difficulty] ?? 0 }
    /// Highest best across every level — what color unlocks are measured against, so
    /// grinding Easy can't cheaply unlock everything.
    var bestOverall: Int { bests.values.max() ?? 0 }
    /// Best on the level that was actually just played, frozen at game over so the
    /// results panel stays truthful if the player switches level before retrying.
    var lastRunBest = 0
    /// True when there is anything worth erasing (drives the "START OVER" button).
    var hasProgress: Bool { bestOverall > 0 || starBalance > 0 }

    /// True when the most recent run strictly beat the previous best (drives the "NEW BEST!" banner).
    var didSetNewBest = false
    var selectedSkinIndex = 0
    /// The highest skin newly unlocked in the most recent run, for the celebration banner.
    var newlyUnlocked: OrbitSkin?
    /// DEBUG-only: when true the ship ignores obstacle collisions, used to hold a stable
    /// mid-run state for capturing marketing screenshots. Never enabled in normal play.
    var screenshotMode = false

    // MARK: Cosmetic ownership

    var ownedCosmetics: Set<String> = []
    var selectedTrailID = "comet"
    var selectedPlanetID = "blue"

    // MARK: Spawning

    private var lastSpawnDistance: Double = 0
    private let spawnHorizon: Double = 7.5

    // MARK: Lifecycle

    /// UserDefaults key holding the best score for one level.
    private nonisolated static func bestKey(_ level: Difficulty) -> String {
        "orbit.best.\(level.rawValue)"
    }

    /// Every key this game writes, used by `resetProgress()`. "orbit.best" is the
    /// pre-difficulty single-best key, still read once for migration.
    private nonisolated static var allDefaultsKeys: [String] {
        ["orbit.best", "orbit.stars", "orbit.skin", "orbit.owned",
         "orbit.trail", "orbit.planet", "orbit.difficulty"]
        + Difficulty.allCases.map(bestKey)
    }

    init() {
        let defaults = UserDefaults.standard

        for level in Difficulty.allCases {
            bests[level] = defaults.integer(forKey: GameModel.bestKey(level))
        }
        // Carry a pre-difficulty best forward into Normal, whose curve matches the
        // original game exactly. Idempotent, so it is safe to run on every launch.
        let legacyBest = defaults.integer(forKey: "orbit.best")
        if legacyBest > bests[.normal, default: 0] {
            bests[.normal] = legacyBest
            defaults.set(legacyBest, forKey: GameModel.bestKey(.normal))
        }

        if let raw = defaults.string(forKey: "orbit.difficulty"),
           let saved = Difficulty(rawValue: raw) {
            difficulty = saved
        }
        speed = difficulty.tuning.baseSpeed

        starBalance = defaults.integer(forKey: "orbit.stars")

        let savedSkin = defaults.integer(forKey: "orbit.skin")
        selectedSkinIndex = min(max(savedSkin, 0), GameModel.skins.count - 1)

        ownedCosmetics = Set(defaults.stringArray(forKey: "orbit.owned") ?? [])
        grantFreeCosmetics()

        if let t = defaults.string(forKey: "orbit.trail"), ownedCosmetics.contains(t) { selectedTrailID = t }
        if let p = defaults.string(forKey: "orbit.planet"), ownedCosmetics.contains(p) { selectedPlanetID = p }
    }

    /// The zero-cost trail and planet are always owned.
    private func grantFreeCosmetics() {
        for item in GameModel.trails where item.cost == 0 { ownedCosmetics.insert(item.id) }
        for item in GameModel.planets where item.cost == 0 { ownedCosmetics.insert(item.id) }
    }

    // MARK: Difficulty

    func selectDifficulty(_ level: Difficulty) {
        guard phase != .playing, level != difficulty else { return }
        difficulty = level
        UserDefaults.standard.set(level.rawValue, forKey: "orbit.difficulty")
        impact(.light)
    }

    // MARK: Start over

    /// Erases every scrap of saved progress and returns the game to a fresh-install
    /// state. Destructive and irreversible — callers must confirm with the player first.
    func resetProgress() {
        let defaults = UserDefaults.standard
        for key in GameModel.allDefaultsKeys { defaults.removeObject(forKey: key) }

        bests = [:]
        lastRunBest = 0
        starBalance = 0
        difficulty = .normal
        selectedSkinIndex = 0
        ownedCosmetics = []
        grantFreeCosmetics()
        selectedTrailID = GameModel.trails[0].id
        selectedPlanetID = GameModel.planets[0].id

        // Drop any run in progress and go back to a clean menu.
        phase = .menu
        score = 0
        stars = 0
        distance = 0
        speed = tuning.baseSpeed
        shipRing = 0
        shipLaneValue = 0
        entities.removeAll()
        particles.removeAll()
        lastSpawnDistance = 0
        shake = 0
        newlyUnlocked = nil
        didSetNewBest = false

        impact(.heavy)
    }

    // MARK: Skins

    var activeSkin: OrbitSkin { GameModel.skins[selectedSkinIndex] }
    var shipColor: Color { activeSkin.color }

    func isUnlocked(_ skin: OrbitSkin) -> Bool { bestOverall >= skin.unlockScore }

    /// The next skin the player has not yet unlocked (nil once everything is earned).
    var nextLockedSkin: OrbitSkin? { GameModel.skins.first { !isUnlocked($0) } }

    var unlockedCount: Int { GameModel.skins.filter { isUnlocked($0) }.count }

    func selectSkin(_ id: Int) {
        guard let index = GameModel.skins.firstIndex(where: { $0.id == id }) else { return }
        guard isUnlocked(GameModel.skins[index]) else { return }
        selectedSkinIndex = index
        UserDefaults.standard.set(index, forKey: "orbit.skin")
        impact(.light)
    }

    // MARK: Cosmetics (shop)

    func isOwned(_ id: String) -> Bool { ownedCosmetics.contains(id) }

    var activeTrail: TrailStyle {
        GameModel.trails.first { $0.id == selectedTrailID } ?? GameModel.trails[0]
    }

    var activePlanet: PlanetTheme {
        GameModel.planets.first { $0.id == selectedPlanetID } ?? GameModel.planets[0]
    }

    /// Tap in the shop: equip if owned, otherwise buy-and-equip if affordable.
    func selectOrBuy(id: String, cost: Int, kind: CosmeticKind) {
        if isOwned(id) {
            equip(id: id, kind: kind)
        } else if starBalance >= cost {
            starBalance -= cost
            ownedCosmetics.insert(id)
            UserDefaults.standard.set(starBalance, forKey: "orbit.stars")
            UserDefaults.standard.set(Array(ownedCosmetics), forKey: "orbit.owned")
            equip(id: id, kind: kind)
            impact(.medium)
        } else {
            impact(.light)   // can't afford
        }
    }

    private func equip(id: String, kind: CosmeticKind) {
        switch kind {
        case .trail:
            selectedTrailID = id
            UserDefaults.standard.set(id, forKey: "orbit.trail")
        case .planet:
            selectedPlanetID = id
            UserDefaults.standard.set(id, forKey: "orbit.planet")
        }
        impact(.light)
    }

    // MARK: Geometry helpers

    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    var minDimension: Double { min(size.width, size.height) }

    func ringRadius(_ ring: Int) -> Double {
        (ring == 0 ? 0.30 : 0.44) * minDimension
    }

    /// The pixel radius the ship is currently drawn at (tween between the two rings).
    var shipRadius: Double {
        let inner = ringRadius(0)
        let outer = ringRadius(1)
        return inner + (outer - inner) * shipLaneValue
    }

    var shipPosition: CGPoint {
        pointOnRing(angle: shipScreenAngle, radius: shipRadius)
    }

    func pointOnRing(angle: Double, radius: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius)
    }

    /// Screen angle for an entity given the current travel distance.
    func screenAngle(for entity: TrackEntity) -> Double {
        shipScreenAngle + (entity.distance - distance)
    }

    // MARK: Input

    func handleTap() {
        switch phase {
        case .menu, .gameOver:
            startRun()
        case .playing:
            shipRing = 1 - shipRing
            impact(.light)
        }
    }

    // MARK: Run control

    func startRun() {
        distance = 0
        speed = tuning.baseSpeed
        score = 0
        stars = 0
        shipRing = 0
        shipLaneValue = 0
        entities.removeAll()
        particles.removeAll()
        lastSpawnDistance = 0
        shake = 0
        newlyUnlocked = nil
        didSetNewBest = false
        phase = .playing

        // Lay down a short safe runway before the first obstacle.
        lastSpawnDistance = tuning.runway
        while lastSpawnDistance < distance + spawnHorizon {
            spawnSlot(at: lastSpawnDistance)
            lastSpawnDistance += currentSlotGap
        }
    }

    private func endRun() {
        phase = .gameOver
        shake = 1.0
        burst(at: shipPosition, color: shipColor, count: 34, speed: 260)

        // Bank the stars collected this run.
        starBalance += stars
        UserDefaults.standard.set(starBalance, forKey: "orbit.stars")

        // Records are per level, but unlocks are measured against the best of all levels.
        let previousOverall = bestOverall
        didSetNewBest = score > best && score > 0
        if didSetNewBest {
            bests[difficulty] = score
            UserDefaults.standard.set(score, forKey: GameModel.bestKey(difficulty))
        }
        lastRunBest = best

        // GameKit keeps the player's best per leaderboard, so submitting every
        // run's score is safe and keeps the board current without extra checks.
        GameCenterManager.shared.submitScore(score, leaderboardID: difficulty.leaderboardID)

        // Highest skin whose threshold we crossed this run.
        newlyUnlocked = GameModel.skins.last {
            $0.unlockScore > previousOverall && $0.unlockScore <= bestOverall && $0.unlockScore > 0
        }
        // Reward the player by immediately equipping their newest color.
        if let unlocked = newlyUnlocked {
            selectSkin(unlocked.id)
        }

        impact(.heavy)
    }

    // MARK: Difficulty curve

    private var currentSlotGap: Double {
        max(tuning.minSlotGap, tuning.startSlotGap - Double(score) * tuning.gapTighten)
    }

    private func spawnSlot(at d: Double) {
        let obstacleRing = Bool.random() ? 0 : 1
        entities.append(TrackEntity(distance: d, ring: obstacleRing, kind: .obstacle))

        // A star often lives on the safe ring — reward the player for switching.
        // Harder levels make that reward scarcer.
        if Double.random(in: 0...1) < tuning.safeStarChance {
            entities.append(TrackEntity(distance: d, ring: 1 - obstacleRing, kind: .star))
        }
    }

    // MARK: Per-frame update

    func update(dt: Double) {
        let dt = min(dt, 1.0 / 30.0)   // clamp huge frame gaps (e.g. after backgrounding)
        time += dt

        ensureBackgroundStars()
        animateShipLane(dt: dt)
        updateParticles(dt: dt)
        if shake > 0 { shake = max(0, shake - dt * 2.2) }

        guard phase == .playing else { return }

        // Ramp difficulty and advance along the track.
        speed = min(tuning.maxSpeed, tuning.baseSpeed + Double(score) * tuning.speedRamp)
        distance += speed * dt

        // Keep the track populated ahead of the ship.
        while lastSpawnDistance < distance + spawnHorizon {
            spawnSlot(at: lastSpawnDistance)
            lastSpawnDistance += currentSlotGap
        }

        resolveContacts()

        // Drop entities that have passed well behind the ship.
        entities.removeAll { $0.distance < distance - 1.4 }
    }

    private func animateShipLane(dt: Double) {
        let target = Double(shipRing)
        let rate = min(1, dt * 16)   // snappy but smooth
        shipLaneValue += (target - shipLaneValue) * rate
    }

    private func resolveContacts() {
        for index in entities.indices {
            let delta = entities[index].distance - distance

            // Count an obstacle as survived once it slips behind the ship.
            if entities[index].kind == .obstacle, !entities[index].scored, delta < 0 {
                entities[index].scored = true
                score += 1
            }

            guard abs(delta) < hitWindow, entities[index].ring == shipRing else { continue }

            switch entities[index].kind {
            case .obstacle:
                if screenshotMode { break }
                endRun()
                return
            case .star where !entities[index].collected:
                entities[index].collected = true
                stars += 1
                score += 2
                burst(at: shipPosition,
                      color: Color(red: 1.0, green: 0.82, blue: 0.28),
                      count: 12, speed: 150)
                impact(.medium)
            default:
                break
            }
        }
    }

    // MARK: Particles

    func burst(at point: CGPoint, color: Color, count: Int, speed: Double) {
        for _ in 0..<count {
            let angle = Double.random(in: 0..<(2 * .pi))
            let mag = Double.random(in: speed * 0.3...speed)
            let life = Double.random(in: 0.35...0.8)
            particles.append(Particle(
                pos: point,
                vel: CGVector(dx: cos(angle) * mag, dy: sin(angle) * mag),
                life: life,
                maxLife: life,
                color: color,
                size: Double.random(in: 2...5)
            ))
        }
    }

    private func updateParticles(dt: Double) {
        for index in particles.indices {
            particles[index].pos.x += particles[index].vel.dx * dt
            particles[index].pos.y += particles[index].vel.dy * dt
            particles[index].vel.dx *= 0.92
            particles[index].vel.dy *= 0.92
            particles[index].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    // MARK: Background field

    private func ensureBackgroundStars() {
        guard backgroundStars.isEmpty, minDimension > 0 else { return }
        let maxRadius = max(size.width, size.height)
        for _ in 0..<110 {
            backgroundStars.append(BackgroundStar(
                angle: Double.random(in: 0..<(2 * .pi)),
                radius: Double.random(in: 0...maxRadius),
                size: Double.random(in: 0.6...2.2),
                alpha: Double.random(in: 0.15...0.7)
            ))
        }
    }

    // MARK: Haptics

    #if os(iOS)
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    #else
    private enum HapticStyle { case light, medium, heavy }
    private func impact(_ style: HapticStyle) {}
    #endif
}
