//
//  SystemObservers.swift
//  Soulsniper
//
//  Created by Arush Wadhawan on 3/27/26.
//

import AppKit
import ApplicationServices
import CoreServices
import Observation

enum AutomationPermissionState: Equatable {
    case granted
    case notDetermined
    case denied
    case appNotRunning
    case unavailable
    case unknown(OSStatus)

    var label: String {
        switch self {
        case .granted:
            return "Allowed"
        case .notDetermined:
            return "Needs Permission"
        case .denied:
            return "Denied"
        case .appNotRunning:
            return "Open App to Check"
        case .unavailable:
            return "Not Installed"
        case .unknown:
            return "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .notDetermined, .appNotRunning:
            return "exclamationmark.circle.fill"
        case .denied, .unknown:
            return "xmark.circle.fill"
        case .unavailable:
            return "minus.circle.fill"
        }
    }
}

@Observable
final class PermissionMonitor {
    var accessibilityTrusted = PermissionMonitor.isAccessibilityTrusted(prompt: false)
    var safariAutomation = PermissionMonitor.automationPermissionStatus(for: "com.apple.Safari", prompt: false)
    var chromeAutomation = PermissionMonitor.automationPermissionStatus(for: "com.google.Chrome", prompt: false)

    func refresh() {
        accessibilityTrusted = PermissionMonitor.isAccessibilityTrusted(prompt: false)
        safariAutomation = PermissionMonitor.automationPermissionStatus(for: "com.apple.Safari", prompt: false)
        chromeAutomation = PermissionMonitor.automationPermissionStatus(for: "com.google.Chrome", prompt: false)
    }

    func requestAccessibilityPermission() {
        _ = PermissionMonitor.isAccessibilityTrusted(prompt: true)
        refresh()
    }

    func requestAutomationPermission(for bundleIdentifier: String) {
        launchApplicationIfNeeded(bundleIdentifier: bundleIdentifier)

        DispatchQueue.global(qos: .userInitiated).async {
            let status = PermissionMonitor.automationPermissionStatus(for: bundleIdentifier, prompt: true)
            DispatchQueue.main.async {
                switch bundleIdentifier {
                case "com.apple.Safari":
                    self.safariAutomation = status
                case "com.google.Chrome":
                    self.chromeAutomation = status
                default:
                    break
                }
            }
        }
    }

    func openAutomationPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func supportsAutomation(bundleIdentifier: String) -> Bool {
        switch bundleIdentifier {
        case "com.apple.Safari", "com.google.Chrome":
            return true
        default:
            return false
        }
    }

    nonisolated static func automationPermissionStatus(for bundleIdentifier: String, prompt: Bool) -> AutomationPermissionState {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil else {
            return .unavailable
        }

        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return .appNotRunning
        }

        var pid = runningApp.processIdentifier
        var addressDesc = AEAddressDesc()
        let createStatus = withUnsafePointer(to: &pid) { pointer in
            AECreateDesc(DescType(typeKernelProcessID), pointer, MemoryLayout<pid_t>.size, &addressDesc)
        }

        guard createStatus == noErr else {
            return .unknown(OSStatus(createStatus))
        }

        defer { AEDisposeDesc(&addressDesc) }

        let status = AEDeterminePermissionToAutomateTarget(&addressDesc, AEEventClass(typeWildCard), AEEventID(typeWildCard), prompt)

        switch status {
        case noErr:
            return .granted
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(procNotFound):
            return .appNotRunning
        default:
            return .unknown(status)
        }
    }

    private func launchApplicationIfNeeded(bundleIdentifier: String) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty,
              let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, _ in }
    }
}

final class MonitorObserver {
    var onDisplaysChanged: (() -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleDisplayChange() {
        onDisplaysChanged?()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
