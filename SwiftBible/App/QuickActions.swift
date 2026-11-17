//
//  QuickActions.swift
//  SwiftBible
//

import Observation
import UIKit

/// Home Screen quick actions (app icon touch-and-hold menu).
///
/// Raw values must match UIApplicationShortcutItemType entries in Info.plist.
enum QuickAction: String {
    case read
    case saved
    case search
}

/// Bridges UIKit scene callbacks to SwiftUI.
///
/// The scene delegate is created by UIKit, not SwiftUI, so it can't reach App-owned @State;
/// a shared instance is the simplest handoff. ContentView observes `pending` and consumes it.
@Observable
final class QuickActionRouter {
    static let shared = QuickActionRouter()

    /// Most recent quick action not yet handled by the UI
    var pending: QuickAction?

    /// Returns true when the shortcut type is recognized
    @discardableResult
    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = QuickAction(rawValue: shortcutItem.type) else { return false }
        pending = action
        return true
    }
}

/// Registers QuickActionSceneDelegate; SwiftUI has no native quick action callback.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Cold launch: shortcut arrives in connection options
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            QuickActionRouter.shared.handle(shortcutItem)
        }
    }

    /// App already running: system calls this instead
    ///
    /// Completion-handler form, not async: the async requirement is nonisolated, so its
    /// non-Sendable UIApplicationShortcutItem can't cross into this main actor-isolated class.
    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActionRouter.shared.handle(shortcutItem))
    }
}
