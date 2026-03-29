//
//  Models.swift
//  Soulsniper
//
//  Created by Arush Wadhawan on 3/27/26.
//

import AppKit
import Foundation

struct WorkspaceState: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var accentHex: String
    var createdAt: Date
    var updatedAt: Date
    var launches: [LaunchTarget]
    var closedBundleIdentifiers: [String]
    var windows: [WindowSnapshot]
    var displaySignature: DisplaySignature
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        accentHex: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        launches: [LaunchTarget],
        closedBundleIdentifiers: [String] = [],
        windows: [WindowSnapshot],
        displaySignature: DisplaySignature,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.accentHex = accentHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.launches = launches
        self.closedBundleIdentifiers = closedBundleIdentifiers
        self.windows = windows
        self.displaySignature = displaySignature
        self.notes = notes
    }

    var appCount: Int {
        Set(launches.map(\.bundleIdentifier)).count
    }
}

struct LaunchTarget: Identifiable, Codable, Hashable {
    var id: UUID
    var bundleIdentifier: String
    var appName: String
    var urls: [String]
    var preferredDisplayID: UInt32?

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        urls: [String] = [],
        preferredDisplayID: UInt32? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.urls = urls
        self.preferredDisplayID = preferredDisplayID
    }

    var primaryURL: String? {
        urls.first
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case bundleIdentifier
        case appName
        case urls
        case url
        case preferredDisplayID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        appName = try container.decode(String.self, forKey: .appName)
        preferredDisplayID = try container.decodeIfPresent(UInt32.self, forKey: .preferredDisplayID)

        if let decodedURLs = try container.decodeIfPresent([String].self, forKey: .urls) {
            urls = decodedURLs
        } else if let decodedURL = try container.decodeIfPresent(String.self, forKey: .url), decodedURL.isEmpty == false {
            urls = [decodedURL]
        } else {
            urls = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(appName, forKey: .appName)
        try container.encode(urls, forKey: .urls)
        try container.encodeIfPresent(preferredDisplayID, forKey: .preferredDisplayID)
    }
}

struct WindowSnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var bundleIdentifier: String
    var appName: String
    var title: String
    var frame: RectCodable
    var displayID: UInt32?
    var order: Int

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        title: String,
        frame: CGRect,
        displayID: UInt32?,
        order: Int
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.title = title
        self.frame = RectCodable(frame)
        self.displayID = displayID
        self.order = order
    }
}

struct RectCodable: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct DisplaySignature: Codable, Hashable {
    var summary: String
    var displays: [DisplayDescriptor]

    @MainActor
    static func current() -> DisplaySignature {
        let screens = NSScreen.screens.compactMap(DisplayDescriptor.init(screen:))
        let summary = screens
            .map { "\($0.name) \($0.width)x\($0.height)" }
            .joined(separator: " + ")
        return DisplaySignature(summary: summary, displays: screens)
    }
}

struct DisplayDescriptor: Identifiable, Codable, Hashable {
    var id: UInt32
    var name: String
    var width: Double
    var height: Double
    var originX: Double
    var originY: Double
    var isPrimary: Bool

    @MainActor
    init?(screen: NSScreen) {
        guard
            let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return nil
        }

        let frame = screen.frame
        id = screenID.uint32Value
        name = screen.localizedName
        width = frame.width
        height = frame.height
        originX = frame.origin.x
        originY = frame.origin.y
        isPrimary = frame.origin == .zero
    }
}

enum RestoreBehavior: String, CaseIterable, Identifiable {
    case full = "Full Restore"
    case layoutOnly = "Layout Only"
    case launchOnly = "Launch Only"

    var id: String { rawValue }
}
