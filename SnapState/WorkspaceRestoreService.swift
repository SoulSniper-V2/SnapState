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
    func restore(state: WorkspaceState, behavior: RestoreBehavior) throws {
        if behavior != .launchOnly, PermissionMonitor.isAccessibilityTrusted(prompt: true) == false {
            throw WorkspaceRestoreError.accessibilityRequired
        }

        if behavior != .layoutOnly {
            restoreLaunchTargets(state.launches)
            closeApps(withBundleIdentifiers: state.closedBundleIdentifiers)
        }

        if behavior != .launchOnly {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                restoreWindowFrames(state.windows)
            }
        }
    }

    private func restoreLaunchTargets(_ targets: [LaunchTarget]) {
        for target in targets {
            let configuration = NSWorkspace.OpenConfiguration()

            if let urlString = target.url, let url = URL(string: urlString) {
                if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) {
                    NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration)
                } else {
                    NSWorkspace.shared.open(url)
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

    private func restoreWindowFrames(_ windows: [WindowSnapshot]) {
        let grouped = Dictionary(grouping: windows, by: \.bundleIdentifier)

        for (bundleIdentifier, snapshots) in grouped {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
                continue
            }

            // Give the app a moment to fully launch and create its windows
            usleep(300_000) // 300ms per app

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

            guard
                result == .success,
                let axWindows = value as? [AXUIElement]
            else {
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
                    usleep(50_000) // 50ms between raising windows
                }
            }
        }

        // Final pass: activate the last app to ensure all windows are visible
        if let lastBundleId = grouped.keys.first(where: { _ in true }),
           let lastApp = NSRunningApplication.runningApplications(withBundleIdentifier: lastBundleId).first {
            lastApp.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
