//
//  WorkspaceSnapshotService.swift
//  Soulsniper
//
//  Created by Arush Wadhawan on 3/27/26.
//

import AppKit
import ApplicationServices

enum WorkspaceSnapshotError: LocalizedError {
    case accessibilityRequired
    case noLaunchTargets

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            return "SnapState needs Accessibility permission to read and restore window positions."
        case .noLaunchTargets:
            return "There were no regular app windows or launchable apps to save."
        }
    }
}

struct WorkspaceSnapshotService {
    func captureWorkspace(named name: String, icon: String, accentHex: String, notes: String) throws -> WorkspaceState {
        guard PermissionMonitor.isAccessibilityTrusted(prompt: true) else {
            throw WorkspaceSnapshotError.accessibilityRequired
        }

        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }

        // Check if Finder is the frontmost app
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let isFinderFrontmost = frontmostApp?.bundleIdentifier == "com.apple.finder"
        let windowSnapshots = captureWindows(for: runningApps, isFinderFrontmost: isFinderFrontmost)
        let appBundleIdentifiersInCurrentDesktop = Set(windowSnapshots.map(\.bundleIdentifier))

        let launches = runningApps.compactMap { app -> LaunchTarget? in
            guard let bundleIdentifier = app.bundleIdentifier else { return nil }

            // Only capture apps that actually have visible windows in the current desktop.
            // This keeps a workspace scoped to the active Space instead of every running app.
            guard appBundleIdentifiersInCurrentDesktop.contains(bundleIdentifier) else {
                return nil
            }

            return LaunchTarget(
                bundleIdentifier: bundleIdentifier,
                appName: app.localizedName ?? bundleIdentifier,
                urls: BrowserURLReader.bestEffortURLs(for: bundleIdentifier),
                preferredDisplayID: nil
            )
        }
        .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }

        guard launches.isEmpty == false || windowSnapshots.isEmpty == false else {
            throw WorkspaceSnapshotError.noLaunchTargets
        }

        return WorkspaceState(
            name: name,
            icon: icon,
            accentHex: accentHex,
            launches: launches,
            windows: windowSnapshots,
            displaySignature: .current(),
            notes: notes
        )
    }

    private func captureWindows(for apps: [NSRunningApplication], isFinderFrontmost: Bool = false) -> [WindowSnapshot] {
        let pairs: [(pid_t, (String, String))] = apps.compactMap { app in
            guard let bundleIdentifier = app.bundleIdentifier else { return nil }
            return (app.processIdentifier, (bundleIdentifier, app.localizedName ?? bundleIdentifier))
        }
        let appLookup = Dictionary(uniqueKeysWithValues: pairs)

        // Get window list with more details - .optionAll gets windows including offscreen ones
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var order = 0
        return infoList.compactMap { info -> WindowSnapshot? in
            guard
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let (bundleIdentifier, appName) = appLookup[pid],
                let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                frame.width > 80,
                frame.height > 60
            else {
                return nil
            }

            // Skip Finder windows unless Finder is frontmost
            if bundleIdentifier == "com.apple.finder" && !isFinderFrontmost {
                return nil
            }

            let title = (info[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = title?.isEmpty == false ? title! : appName
            let layer = info[kCGWindowLayer as String] as? Int ?? 0

            // Skip utility windows (layer > 0 means floating/utility windows)
            guard layer == 0 else { return nil }

            let snapshot = WindowSnapshot(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                title: resolvedTitle,
                frame: frame,
                displayID: DisplayMapper.displayID(containing: frame),
                order: order
            )
            order += 1
            return snapshot
        }
    }
}

enum BrowserURLReader {
    static func bestEffortURLs(for bundleIdentifier: String) -> [String] {
        switch bundleIdentifier {
        case "com.apple.Safari":
            return AppleScriptRunner.runLines(
                """
                tell application "Safari"
                    if (count of windows) is 0 then return ""
                    set output to {}
                    repeat with w in windows
                        try
                            set end of output to (URL of current tab of w)
                        end try
                    end repeat
                    set AppleScript's text item delimiters to linefeed
                    set joinedOutput to output as string
                    set AppleScript's text item delimiters to ""
                    return joinedOutput
                end tell
                """
            )
        case "com.google.Chrome":
            return AppleScriptRunner.runLines(
                """
                tell application "Google Chrome"
                    if (count of windows) is 0 then return ""
                    set output to {}
                    repeat with w in windows
                        try
                            set end of output to (URL of active tab of w)
                        end try
                    end repeat
                    set AppleScript's text item delimiters to linefeed
                    set joinedOutput to output as string
                    set AppleScript's text item delimiters to ""
                    return joinedOutput
                end tell
                """
            )
        default:
            return []
        }
    }
}

enum AppleScriptRunner {
    static func run(_ source: String) -> String? {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let output = script?.executeAndReturnError(&error).stringValue
        if error != nil {
            return nil
        }
        return output?.isEmpty == false ? output : nil
    }

    static func runLines(_ source: String) -> [String] {
        guard let output = run(source) else {
            return []
        }

        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}

enum DisplayMapper {
    static func displayID(containing rect: CGRect) -> UInt32? {
        let displays: [(UInt32, CGRect)] = NSScreen.screens.compactMap { screen in
            guard
                let idNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else {
                return nil
            }
            return (idNumber.uint32Value, screen.frame)
        }
        return displays.first(where: { $0.1.intersects(rect) })?.0
    }
}
