//
//  WorkspaceRestoreService.swift
//  Soulsniper
//
//  Created by Arush Wadhawan on 3/27/26.
//

import AppKit
import ApplicationServices

enum WorkspaceRestoreError: LocalizedError {
    case accessibilityRequired

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            return "Accessibility permission is required to reposition windows."
        }
    }
}

struct WorkspaceRestoreService {
    private let appLaunchSettlingDelay: TimeInterval = 1.2
    private let browserURLRestoreDelay: TimeInterval = 0.35
    private let windowPollingTimeout: TimeInterval = 8.0
    private let windowPollingInterval: useconds_t = 150_000
    private let raiseWindowInterval: useconds_t = 50_000

    func restore(state: WorkspaceState, behavior: RestoreBehavior) throws {
        if behavior != .launchOnly, PermissionMonitor.isAccessibilityTrusted(prompt: true) == false {
            throw WorkspaceRestoreError.accessibilityRequired
        }

        if behavior != .layoutOnly {
            restoreLaunchTargets(state.launches)
            closeApps(withBundleIdentifiers: state.closedBundleIdentifiers)
        }

        if behavior != .launchOnly {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + appLaunchSettlingDelay) {
                restoreWindowFrames(state.windows)
            }
        }
    }

    private func restoreLaunchTargets(_ targets: [LaunchTarget]) {
        for target in targets {
            let configuration = NSWorkspace.OpenConfiguration()
            let urls = target.urls.compactMap(URL.init(string:))

            if urls.isEmpty == false {
                if restoreBrowserURLs(urls, for: target.bundleIdentifier) {
                    continue
                }

                if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) {
                    NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration)
                } else {
                    urls.forEach { NSWorkspace.shared.open($0) }
                }
                continue
            }

            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) else {
                continue
            }
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration)
        }
    }

    private func closeApps(withBundleIdentifiers identifiers: [String]) {
        for identifier in identifiers {
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier).forEach { $0.terminate() }
        }
    }

    private func restoreBrowserURLs(_ urls: [URL], for bundleIdentifier: String) -> Bool {
        let normalizedURLs = urls
            .map(\.absoluteString)
            .filter { $0.isEmpty == false }

        guard normalizedURLs.isEmpty == false else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        let supportedBrowsers = [
            "com.apple.Safari",
            "com.apple.SafariTechnologyPreview",
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "org.chromium.Chromium",
            "company.thebrowser.Browser" // Arc
        ]

        guard supportedBrowsers.contains(bundleIdentifier) else {
            return false
        }

        if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration)
        }

        let script = browserRestoreScript(for: bundleIdentifier, urls: normalizedURLs)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + browserURLRestoreDelay) {
            let succeeded = AppleScriptRunner.run(script) != nil
            if succeeded == false, let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                let fallbackURLs = normalizedURLs.compactMap(URL.init(string:))
                NSWorkspace.shared.open(fallbackURLs, withApplicationAt: applicationURL, configuration: configuration)
            }
        }
        return true
    }

    private func browserRestoreScript(for bundleIdentifier: String, urls: [String]) -> String {
        let quotedURLs = urls.map(Self.appleScriptStringLiteral).joined(separator: ", ")
        let appIdentifier = Self.appleScriptStringLiteral(bundleIdentifier)

        return """
        set targetURLs to {\(quotedURLs)}
        tell application id \(appIdentifier)
            activate
            repeat with targetURL in targetURLs
                try
                    open location (targetURL as text)
                end try
            end repeat
        end tell
        return "ok"
        """
    }

    nonisolated private static func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func restoreWindowFrames(_ windows: [WindowSnapshot]) {
        let grouped = Dictionary(grouping: windows, by: \.bundleIdentifier)

        for (bundleIdentifier, snapshots) in grouped {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
                continue
            }

            guard let axWindows = waitForWindows(of: app, timeout: windowPollingTimeout) else {
                continue
            }

            // Sort by order (z-order) - lower index = higher in stack
            let orderedSnapshots = snapshots.sorted { $0.order < $1.order }

            // Restore positions for all windows
            for (index, snapshot) in orderedSnapshots.enumerated() where index < axWindows.count {
                let frame = snapshot.frame.cgRect
                var point = CGPoint(x: frame.origin.x, y: frame.origin.y)
                var dimensions = CGSize(width: frame.width, height: frame.height)
                let position = AXValueCreate(.cgPoint, &point)
                let size = AXValueCreate(.cgSize, &dimensions)

                if let position {
                    AXUIElementSetAttributeValue(axWindows[index], kAXPositionAttribute as CFString, position)
                }
                if let size {
                    AXUIElementSetAttributeValue(axWindows[index], kAXSizeAttribute as CFString, size)
                }
            }

            // Bring windows to front in reverse z-order (topmost last so it ends up on top)
            // This recreates the original stacking order
            for snapshot in orderedSnapshots.reversed() {
                if let index = orderedSnapshots.firstIndex(where: { $0.id == snapshot.id }),
                   index < axWindows.count {
                    AXUIElementSetAttributeValue(axWindows[index], "AXRaised" as CFString, axWindows[index])
                    usleep(raiseWindowInterval)
                }
            }
        }

        // Final pass: activate the last app to ensure all windows are visible
        if let lastBundleId = grouped.keys.first(where: { _ in true }),
           let lastApp = NSRunningApplication.runningApplications(withBundleIdentifier: lastBundleId).first {
            lastApp.activate()
        }
    }

    private func waitForWindows(of app: NSRunningApplication, timeout: TimeInterval) -> [AXUIElement]? {
        let deadline = Date().addingTimeInterval(timeout)
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        repeat {
            if let windows = copyWindows(from: appElement), windows.isEmpty == false {
                return windows
            }

            usleep(windowPollingInterval)
        } while Date() < deadline && app.isTerminated == false

        return copyWindows(from: appElement)
    }

    private func copyWindows(from appElement: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

        guard result == .success else {
            return nil
        }

        return value as? [AXUIElement]
    }
}
