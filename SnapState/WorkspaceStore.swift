//
//  WorkspaceStore.swift
//  Soulsniper
//
//  Created by Arush Wadhawan on 3/27/26.
//

import AppKit
import Observation

@Observable
final class WorkspaceStore {
    var states: [WorkspaceState] = []
    var selectedStateID: WorkspaceState.ID?
    var isCapturing = false
    var isRestoring = false
    var captureError: String?
    var restoreError: String?
    var lastMonitorEvent: Date?
    var statusMessage = "Ready to capture your workspace."
    var pendingAutoRestoreStateID: WorkspaceState.ID?

    let permissionMonitor = PermissionMonitor()
    let snapshotService = WorkspaceSnapshotService()
    let restoreService = WorkspaceRestoreService()
    let monitorObserver = MonitorObserver()

    private let saveURL: URL

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = supportURL.appendingPathComponent("SnapState", isDirectory: true)
        saveURL = directory.appendingPathComponent("states.json")

        load()

        if states.isEmpty {
            states = WorkspaceState.samples
            selectedStateID = states.first?.id
            save()
        } else {
            selectedStateID = states.first?.id
        }

        monitorObserver.onDisplaysChanged = { [weak self] in
            self?.handleDisplayChange()
        }
    }

    var selectedState: WorkspaceState? {
        get { states.first(where: { $0.id == selectedStateID }) }
        set { selectedStateID = newValue?.id }
    }

    var currentDisplaySignature: DisplaySignature {
        DisplaySignature.current()
    }

    func captureState(name: String, icon: String, accentHex: String, notes: String) {
        isCapturing = true
        captureError = nil

        defer { isCapturing = false }

        do {
            let snapshot = try snapshotService.captureWorkspace(
                named: name,
                icon: icon,
                accentHex: accentHex,
                notes: notes
            )

            if let index = states.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                var updated = snapshot
                updated.id = states[index].id
                updated.createdAt = states[index].createdAt
                states[index] = updated
                selectedStateID = updated.id
                statusMessage = "Updated \(updated.name)."
            } else {
                states.insert(snapshot, at: 0)
                selectedStateID = snapshot.id
                statusMessage = "Saved \(snapshot.name)."
            }

            save()
        } catch {
            captureError = error.localizedDescription
            statusMessage = "Capture failed."
        }
    }

    func restore(_ state: WorkspaceState, behavior: RestoreBehavior) {
        isRestoring = true
        restoreError = nil

        defer { isRestoring = false }

        do {
            try restoreService.restore(state: state, behavior: behavior)
            statusMessage = "Restored \(state.name)."
        } catch {
            restoreError = error.localizedDescription
            statusMessage = "Restore failed."
        }
    }

    func delete(_ state: WorkspaceState) {
        states.removeAll { $0.id == state.id }
        if selectedStateID == state.id {
            selectedStateID = states.first?.id
        }
        save()
    }

    func queueAutoRestore(for state: WorkspaceState) {
        pendingAutoRestoreStateID = state.id
        statusMessage = "Auto-restore armed for \(state.name)."
    }

    private func handleDisplayChange() {
        lastMonitorEvent = .now

        guard let pendingID = pendingAutoRestoreStateID,
              let state = states.first(where: { $0.id == pendingID }) else {
            statusMessage = "Display layout changed."
            return
        }

        do {
            try restoreService.restore(state: state, behavior: .layoutOnly)
            statusMessage = "Display change detected. Restored \(state.name)."
        } catch {
            restoreError = error.localizedDescription
            statusMessage = "Detected monitor change, but restore failed."
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            states = try decoder.decode([WorkspaceState].self, from: data)
        } catch {
            captureError = "Could not read saved states."
        }
    }

    func persistChanges() {
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: saveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.pretty.encode(states)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            captureError = "Could not save workspace states."
        }
    }
}

extension WorkspaceState {
    static let samples: [WorkspaceState] = [
        WorkspaceState(
            name: "Coding Mode",
            icon: "chevron.left.forwardslash.chevron.right",
            accentHex: "#5B8CFF",
            launches: [
                LaunchTarget(bundleIdentifier: "com.apple.Safari", appName: "Safari", url: "https://jira.atlassian.com"),
                LaunchTarget(bundleIdentifier: "com.tinyspeck.slackmacgap", appName: "Slack"),
                LaunchTarget(bundleIdentifier: "com.microsoft.VSCode", appName: "VS Code")
            ],
            closedBundleIdentifiers: ["com.spotify.client"],
            windows: [],
            displaySignature: .current(),
            notes: "Two-monitor dev setup with comms and code."
        ),
        WorkspaceState(
            name: "Weekend Mode",
            icon: "sun.max",
            accentHex: "#FF8A5B",
            launches: [
                LaunchTarget(bundleIdentifier: "com.apple.Music", appName: "Music"),
                LaunchTarget(bundleIdentifier: "com.apple.MobileSMS", appName: "Messages")
            ],
            closedBundleIdentifiers: [
                "com.tinyspeck.slackmacgap",
                "com.docker.docker"
            ],
            windows: [],
            displaySignature: .current(),
            notes: "Shuts down work apps and opens personal basics."
        )
    ]
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
