//
//  ContentView.swift
//  SnapState
//
//  Created by Arush Wadhawan on 3/27/26.
//

import SwiftUI

// MARK: - Menu Bar View (Primary Interface)
struct MenuBarContentView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var quickCaptureName = ""
    @State private var showingQuickCapture = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SnapState")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingQuickCapture.toggle()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Quick Capture
            if showingQuickCapture {
                HStack(spacing: 8) {
                    TextField("Name this setup...", text: $quickCaptureName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                    Button {
                        if !quickCaptureName.isEmpty {
                            store.captureState(name: quickCaptureName, icon: "rectangle.3.group", accentHex: "#5B8CFF", notes: "")
                            quickCaptureName = ""
                            showingQuickCapture = false
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(quickCaptureName.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider().opacity(0.3)

            // States Grid
            if store.states.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No workspaces yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Click + to capture")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(store.states.prefix(6)) { state in
                        StateCard(state: state) {
                            store.restore(state, behavior: .full)
                        }
                    }
                }
                .padding(12)
            }

            Divider().opacity(0.3)

            // Footer
            HStack(spacing: 16) {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gear")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "xmark")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct StateCard: View {
    let state: WorkspaceState
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false

    private var accentColor: Color {
        Color(hex: state.accentHex)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: state.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(accentColor)
                    Spacer()
                    Text("\(state.appCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(state.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text("\(state.windows.count) windows")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(isHovering ? 0.2 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accentColor.opacity(isHovering ? 0.4 : 0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Main Settings Window
struct ContentView: View {
    @Environment(WorkspaceStore.self) private var store
    @State private var selectedState: WorkspaceState?
    @State private var editingName = ""
    @State private var editingIcon = ""
    @State private var editingAccent = ""

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                List(selection: $selectedState) {
                    Section("Workspaces") {
                        ForEach(store.states) { state in
                            SidebarRow(state: state)
                                .tag(state)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.delete(store.states[index])
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack {
                    Button {
                        store.captureState(name: "New Setup", icon: "rectangle.3.group", accentHex: "#5B8CFF", notes: "")
                    } label: {
                        Label("Capture Current", systemImage: "camera")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                }
                .padding(12)
            }
            .frame(minWidth: 200, maxWidth: 260)

            // Detail
            if let state = selectedState {
                DetailView(state: state, store: store)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Select a workspace")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onChange(of: store.states) { _, newStates in
            if selectedState == nil, let first = newStates.first {
                selectedState = first
            }
        }
    }
}

struct SidebarRow: View {
    let state: WorkspaceState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: state.accentHex))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.name)
                    .font(.system(size: 13, weight: .medium))
                Text("\(state.appCount) apps · \(state.windows.count) windows")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DetailView: View {
    let state: WorkspaceState
    let store: WorkspaceStore

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var accentHex: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: accentHex).opacity(0.2))
                            .frame(width: 64, height: 64)
                        Image(systemName: icon.isEmpty ? "rectangle.3.group" : icon)
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: accentHex))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $name)
                            .font(.title2.bold())
                            .textFieldStyle(.plain)

                        Text("Last updated \(state.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Restore") {
                        store.restore(state, behavior: .full)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Divider()

                // Customize
                GroupBox("Customize") {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Icon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("rectangle.3.group", text: $icon)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accent Color")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("#5B8CFF", text: $accentHex)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                Circle()
                                    .fill(Color(hex: accentHex))
                                    .frame(width: 20, height: 20)
                            }
                        }

                        Spacer()

                        Button("Update") {
                            updateState()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                }

                // Apps
                GroupBox("Apps to Launch (\(state.launches.count))") {
                    if state.launches.isEmpty {
                        Text("No apps captured")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(state.launches) { target in
                                AppTag(name: target.appName, url: target.url)
                            }
                        }
                        .padding(8)
                    }
                }

                // Apps to Close
                if !state.closedBundleIdentifiers.isEmpty {
                    GroupBox("Apps to Close (\(state.closedBundleIdentifiers.count))") {
                        FlowLayout(spacing: 8) {
                            ForEach(state.closedBundleIdentifiers, id: \.self) { bundleId in
                                Text(bundleId.components(separatedBy: ".").last ?? bundleId)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.red.opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(8)
                    }
                }

                // Windows
                GroupBox("Window Positions (\(state.windows.count))") {
                    if state.windows.isEmpty {
                        Text("No window positions captured")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(state.windows.prefix(10)) { window in
                                HStack {
                                    Text(window.appName)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(window.title)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(Int(window.frame.width))×\(Int(window.frame.height))")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            if state.windows.count > 10 {
                                Text("+ \(state.windows.count - 10) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                    }
                }

                // Monitor Auto-Restore
                GroupBox("Monitor Plug-In") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-restore when monitor connected")
                                .font(.system(size: 13))
                            Text("Arms this workspace to restore automatically when you plug in an external display")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Arm") {
                            store.queueAutoRestore(for: state)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                }

                // Danger Zone
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delete Workspace")
                                .font(.system(size: 13))
                            Text("This cannot be undone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Delete", role: .destructive) {
                            store.delete(state)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                } label: {
                    Label("Danger Zone", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .onAppear { syncFromState() }
        .onChange(of: state) { _, _ in syncFromState() }
    }

    private func syncFromState() {
        name = state.name
        icon = state.icon
        accentHex = state.accentHex
    }

    private func updateState() {
        guard let index = store.states.firstIndex(where: { $0.id == state.id }) else { return }
        var updated = store.states[index]
        updated.name = name
        updated.icon = icon
        updated.accentHex = accentHex
        updated.updatedAt = .now
        store.states[index] = updated
    }
}

struct AppTag: View {
    let name: String
    let url: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
            if url != nil {
                Image(systemName: "link")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: clean).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xff) / 255
        let green = Double((int >> 8) & 0xff) / 255
        let blue = Double(int & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
