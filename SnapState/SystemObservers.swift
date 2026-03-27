//
//  SystemObservers.swift
//  Soulsniper
//
//  Created by Arush Wadhawan on 3/27/26.
//

import AppKit
import ApplicationServices

@Observable
final class PermissionMonitor {
    var accessibilityTrusted = PermissionMonitor.isAccessibilityTrusted(prompt: false)

    func refresh() {
        accessibilityTrusted = PermissionMonitor.isAccessibilityTrusted(prompt: false)
    }

    static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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
