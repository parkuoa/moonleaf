//
//  ContentView.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var service = macpaperService()
    @State private var selectedTab: TabSelection = .wallpapers
    @AppStorage("glassBackground") private var glassBackground = false
    @State private var showSortDropdown = false

    enum TabSelection: CaseIterable {
        case wallpapers
        case browse

        var title: String {
            switch self {
            case .wallpapers: return NSLocalizedString("mgr_library_title", value: "Library", comment: "library")
            case .browse: return NSLocalizedString("mgr_browse_title", comment: "browse")
            }
        }

        var icon: String {
            switch self {
            case .wallpapers: return "photo.on.rectangle"
            case .browse: return "globe"
            }
        }
    }

    @Namespace private var tabAnimation

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                // Main content
                ZStack {
                Group {
                    switch selectedTab {
                    case .wallpapers:
                        ManagerView()
                            .environmentObject(service)
                    case .browse:
                        BrowseView()
                            .environmentObject(service)
                    }
                }
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Top Bar
            ZStack {
                // Center: Tab Switcher
                HStack(spacing: 8) {
                    Spacer()
                    
                    // Spacer of same width (32 button width + 8 spacing) to offset settings button and keep tabs centered
                    Spacer().frame(width: 40)
                    
                    HStack(spacing: 2) {
                        ForEach(TabSelection.allCases, id: \.self) { tab in
                            TabButton(
                                title: tab.title,
                                icon: tab.icon,
                                isSelected: selectedTab == tab,
                                namespace: tabAnimation,
                                action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedTab = tab }
                                }
                            )
                        }
                    }
                    .padding(3)
                    .background {
                        Capsule()
                            .fill(glassBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial))
                            .overlay {
                                Capsule()
                                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                            }
                    }
                    
                    // Settings Button
                    Button(action: { show_settings() }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }

                // Right: Top-right actions stack
                HStack {
                    Spacer()
                    if selectedTab == .wallpapers {
                        HStack(spacing: 12) {
                            // Kofi Button
                            Button(action: {
                                if let url = URL(string: "https://ko-fi.com/naomisphere") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                if let kofi_cup = NSImage(named: ".kofi") {
                                    Image(nsImage: kofi_cup)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                        .padding(8)
                                        .background {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .overlay {
                                                    Circle()
                                                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                                }
                                        }
                                }
                            }
                            .buttonStyle(.plain)

                            // Favorite Toggle Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    service.showFavoritesOnly.toggle()
                                }
                            }) {
                                Image(systemName: service.showFavoritesOnly ? "star.fill" : "star")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(service.showFavoritesOnly ? Color.accent : Color.primary)
                                    .frame(width: 16, height: 16)
                                    .padding(8)
                                    .background {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay {
                                                Circle()
                                                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                            }
                                    }
                            }
                            .buttonStyle(.plain)

                            // Filters / Sort Button (arrow.up.arrow.down)
                            Button(action: { showSortDropdown.toggle() }) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .frame(width: 16, height: 16)
                                    .padding(8)
                                    .background {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay {
                                                Circle()
                                                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                            }
                                    }
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showSortDropdown, arrowEdge: .bottom) {
                                VStack(spacing: 4) {
                                    ForEach(macpaperService.LocalSortMode.allCases, id: \.self) { mode in
                                        Button(action: { service.setLocalSort(mode); showSortDropdown = false }) {
                                            HStack {
                                                Text(mode.displayName)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(service.localSort == mode ? .primary : .secondary)
                                                Spacer()
                                                if service.localSort == mode {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .semibold))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(service.localSort == mode ? 0.08 : 0.001)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(8)
                                .frame(width: 160)
                            }
                        }
                        .padding(.trailing, 24)
                    } else if selectedTab == .browse {
                        BrowseTopActionsView()
                            .padding(.trailing, 24)
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background {
                VStack(spacing: 0) {
                    VariableBlurView(maxBlurRadius: 20, direction: .blurredTopClearBottom)
                        .frame(height: 72)
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
        .focusable(false)

            if service.showPreview, let wallpaper = service.previewWallpaper {
                QuickPreviewOverlay(
                    wallpaper: wallpaper,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            service.showPreview = false
                            service.previewWallpaper = nil
                        }
                    }
                )
                .environmentObject(service)
                .transition(.opacity)
                .zIndex(999)
            }
        }
    }

    private func show_settings() {
        let settingsView = SettingsView()
            .environmentObject(service)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        if let managerWindow = NSApp.keyWindow {
            let managerFrame = managerWindow.frame
            let settingsSize = window.frame.size
            
            let x = managerFrame.midX - settingsSize.width / 2
            let y = managerFrame.midY - settingsSize.height / 2
            
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
        
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.primary : (isHovered ? Color.primary.opacity(0.7) : Color.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.mainSurface)
                        .overlay {
                            Capsule()
                                .stroke(.primary.opacity(0.1), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
    }
}

