//
//  GameCenterLeaderboardView.swift
//  vibe game
//
//  ORBIT — presents Apple's native Game Center leaderboard UI, opened to
//  the given leaderboard. Wrapped for SwiftUI since GKGameCenterViewController
//  is a platform view controller (UIKit on iOS, AppKit on macOS).
//

import GameKit
import SwiftUI

#if os(iOS)
struct GameCenterLeaderboardView: UIViewControllerRepresentable {
    let leaderboardID: String
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(
            leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime
        )
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            isPresented = false
        }
    }
}
#elseif os(macOS)
struct GameCenterLeaderboardView: NSViewControllerRepresentable {
    let leaderboardID: String
    @Binding var isPresented: Bool

    func makeNSViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(
            leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime
        )
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateNSViewController(_ nsViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            isPresented = false
        }
    }
}
#endif
