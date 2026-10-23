//
//  GameCenterManager.swift
//  vibe game
//
//  ORBIT — thin wrapper around GameKit: authenticates the local player at
//  launch and submits scores to the per-difficulty leaderboards. Every
//  method no-ops quietly when Game Center isn't available (simulator
//  without a signed-in account, parental restrictions, no network), since
//  none of this is required to play a run.
//

import GameKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@Observable
final class GameCenterManager {
    static let shared = GameCenterManager()

    private(set) var isAuthenticated = false

    private init() {}

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let viewController {
                Self.present(viewController)
                return
            }
            self.isAuthenticated = error == nil && GKLocalPlayer.local.isAuthenticated
        }
    }

    func submitScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated, score > 0 else { return }
        Task {
            try? await GKLeaderboard.submitScore(
                score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]
            )
        }
    }

    #if os(iOS)
    private static func present(_ viewController: UIViewController) {
        rootViewController?.present(viewController, animated: true)
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }?.rootViewController
    }
    #elseif os(macOS)
    private static func present(_ viewController: NSViewController) {
        NSApplication.shared.keyWindow?.contentViewController?.presentAsSheet(viewController)
    }
    #endif
}
