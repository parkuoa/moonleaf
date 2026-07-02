//
//  Components.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI
import ImageIO
import AVFoundation

struct RippleButton<Label: View>: View {
    var cornerRadius: CGFloat = 14
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @AppStorage("enableRipple") private var enableRipple = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                label()

                if enableRipple {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                        .frame(width: 80, height: 80)
                        .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { if enableRipple { fire() } else { action() } }
    }

    private func fire() {
        rippleScale = 0
        rippleOpacity = 0.7
        withAnimation(.easeOut(duration: 0.45)) {
            rippleScale = 2.2
            rippleOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action() }
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var bounce = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounce.toggle() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bounce = false }
            }
            action()
        }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(Font(font_loader.bold(size: 14)))
                .foregroundStyle(isFavorite ? Color.accent : Color.white)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .scaleEffect(bounce ? 1.4 : (isHovered ? 1.15 : 1.0))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering } }
    }
}

struct DownloadedCheckButton: View {
    @State private var isHovered = false

    var body: some View {
        Button(action: {}) {
            Image(systemName: "checkmark")
                .font(Font(font_loader.bold(size: 13)))
                .foregroundStyle(Color.accent)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CardMenuButton: View {
    let isStillWallpaper: Bool
    @Binding var isMenuOpen: Bool
    let onRename: () -> Void
    let onExportOriginal: () -> Void
    let onExportCustom: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { isMenuOpen.toggle() }) {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        }
                }
                .scaleEffect(isHovered ? 1.15 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .popover(isPresented: $isMenuOpen, arrowEdge: .bottom) {
            CardMenuContent(
                isStillWallpaper: isStillWallpaper,
                showMenu: $isMenuOpen,
                onRename: onRename,
                onExportOriginal: onExportOriginal,
                onExportCustom: onExportCustom,
                onDelete: onDelete
            )
        }
    }
}

struct CardMenuContent: View {
    let isStillWallpaper: Bool
    @Binding var showMenu: Bool
    let onRename: () -> Void
    let onExportOriginal: () -> Void
    let onExportCustom: () -> Void
    let onDelete: () -> Void
    
    @State private var showExportSubmenu = false
    
    var body: some View {
        VStack(spacing: 4) {
            if showExportSubmenu {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showExportSubmenu = false } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle(hoverColor: Color.primary.opacity(0.08)))
                
                Divider().padding(.horizontal, 4)
                
                Button(action: { showMenu = false; onExportOriginal() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc")
                            .font(.system(size: 12))
                        Text("Original Size")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle(hoverColor: Color.primary.opacity(0.08)))
                
                Button(action: { showMenu = false; onExportCustom() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "crop")
                            .font(.system(size: 12))
                        Text("Custom Ratio")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle(hoverColor: Color.primary.opacity(0.08)))
                
            } else {
                Button(action: { showMenu = false; onRename() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        Text("Rename")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle(hoverColor: Color.primary.opacity(0.08)))
                
                if isStillWallpaper {
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showExportSubmenu = true } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 12))
                            Text("Export")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MenuButtonStyle(hoverColor: Color.primary.opacity(0.08)))
                } else {
                    Button(action: { showMenu = false; onExportOriginal() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 12))
                            Text("Export Original")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MenuButtonStyle(hoverColor: Color.primary.opacity(0.08)))
                }
                
                Divider().padding(.horizontal, 4)
                
                Button(action: { showMenu = false; onDelete() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle(hoverColor: Color.red, hoverTextColor: .white, defaultTextColor: .red))
            }
        }
        .padding(6)
        .frame(width: 160)
    }
}

struct MenuButtonStyle: ButtonStyle {
    var hoverColor: Color
    var hoverTextColor: Color = .primary
    var defaultTextColor: Color = .primary
    
    func makeBody(configuration: Configuration) -> some View {
        MenuButtonView(
            configuration: configuration,
            hoverColor: hoverColor,
            hoverTextColor: hoverTextColor,
            defaultTextColor: defaultTextColor
        )
    }
    
    private struct MenuButtonView: View {
        let configuration: Configuration
        let hoverColor: Color
        let hoverTextColor: Color
        let defaultTextColor: Color
        
        @State private var isHovered = false
        
        var body: some View {
            configuration.label
                .foregroundStyle(isHovered ? hoverTextColor : defaultTextColor)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? hoverColor : Color.clear)
                }
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHovered = hovering
                    }
                }
                .opacity(configuration.isPressed ? 0.75 : 1.0)
        }
    }
}

extension NSColor {
    static var mainSurface: NSColor {
        return NSColor(named: "main-surfece") ?? NSColor(srgbRed: 0.08, green: 0.10, blue: 0.18, alpha: 0.95)
    }
    static var secondarySurface: NSColor {
        return NSColor(named: "Secondary-surfece") ?? NSColor(srgbRed: 0.14, green: 0.16, blue: 0.24, alpha: 0.8)
    }
    static var borderColor: NSColor {
        return NSColor(named: "border-color") ?? NSColor.gray.withAlphaComponent(0.2)
    }
    static var content100: NSColor {
        return NSColor(named: "content-100") ?? NSColor.labelColor
    }
    static var content200: NSColor {
        return NSColor(named: "content-200") ?? NSColor.secondaryLabelColor
    }
    static var accent: NSColor {
        return NSColor(named: "accent") ?? NSColor.systemBlue
    }
}

extension Color {
    static let mainSurface = Color(NSColor.mainSurface)
    static let secondarySurface = Color(NSColor.secondarySurface)
    static let borderColor = Color(NSColor.borderColor)
    static let content100 = Color(NSColor.content100)
    static let content200 = Color(NSColor.content200)
    static let accent = Color(NSColor.accent)
}

// MARK: - VMasonry Layout (Layout protocol, macOS 13+)

struct VMasonry: Layout {
    var columns: Int
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(columns: Int = 3, spacing: CGFloat = 16) {
        self.columns = max(1, columns)
        self.horizontalSpacing = spacing
        self.verticalSpacing = spacing
    }

    init(columns: Int = 3, horizontalSpacing: CGFloat = 16, verticalSpacing: CGFloat = 16) {
        self.columns = max(1, columns)
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        let colWidth = columnWidth(totalWidth: width)
        var colHeights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let colIndex = shortestColumn(colHeights)
            let childSize = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            if colHeights[colIndex] > 0 {
                colHeights[colIndex] += verticalSpacing
            }
            colHeights[colIndex] += childSize.height
        }

        let maxHeight = colHeights.max() ?? 0
        return CGSize(width: width, height: maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let colWidth = columnWidth(totalWidth: bounds.width)
        var colHeights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let colIndex = shortestColumn(colHeights)
            let x = bounds.minX + CGFloat(colIndex) * (colWidth + horizontalSpacing)
            let y = bounds.minY + colHeights[colIndex]

            if colHeights[colIndex] > 0 {
                colHeights[colIndex] += verticalSpacing
            }

            let childSize = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            subview.place(
                at: CGPoint(x: x, y: bounds.minY + colHeights[colIndex]),
                proposal: ProposedViewSize(width: colWidth, height: childSize.height)
            )
            colHeights[colIndex] += childSize.height
        }
    }

    private func columnWidth(totalWidth: CGFloat) -> CGFloat {
        let totalSpacing = horizontalSpacing * CGFloat(columns - 1)
        return max(0, (totalWidth - totalSpacing) / CGFloat(columns))
    }

    private func shortestColumn(_ heights: [CGFloat]) -> Int {
        var minIndex = 0
        for i in 1..<heights.count {
            if heights[i] < heights[minIndex] {
                minIndex = i
            }
        }
        return minIndex
    }
}

struct WallpaperCard: View {
    let wallpaper: endup_wp
    let isActive: Bool
    let cardIsSelected: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onExport: (Bool) -> Void
    let onQuickPreview: () -> Void
    
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var showScreenPicker = false
    @EnvironmentObject private var service: macpaperService
    @State private var aspect: CGFloat = 1.5
    @State private var isMenuOpen = false
    @State private var isHoveredSet = false
    
    private static var aspectCache = [String: CGFloat]()
    
    private var isStillWallpaper: Bool {
        let ext = (wallpaper.path as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png"].contains(ext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            previewSection
                .frame(maxWidth: .infinity)
            WallpaperCardInfo(wallpaper: wallpaper, isEditing: $isEditing, onRename: onRename)
                .padding(.bottom, 6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if service.isSelectionMode {
                if service.selectedWallpapers.contains(wallpaper.id) {
                    service.selectedWallpapers.remove(wallpaper.id)
                } else {
                    service.selectedWallpapers.insert(wallpaper.id)
                }
            } else {
                onTap()
            }
        }
        .onAppear {
            service.refreshScreenCount()
            loadAspectRatio()
        }
        .onChange(of: wallpaper.path) { _ in
            loadAspectRatio()
        }
    }

    private var previewSection: some View {
        ZStack {
            Rectangle()
                .fill(Color.brown.opacity(0.2))
            
            let ext = (wallpaper.path as NSString).pathExtension.lowercased()
            
            if wallpaper.isFolder {
                VStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            } else if ["gif", "jpg", "jpeg", "png"].contains(ext) {
                LazyImagePreview(path: wallpaper.path)
            } else if ["mp4", "mov"].contains(ext) {
                videoPreview(videoURL: URL(fileURLWithPath: wallpaper.path))
                    .clipped()
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                            .background {
                                Circle()
                                    .fill(.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
                    }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }
            
            if !service.isSelectionMode && (isHovered || isActive || isMenuOpen) {
                overlayControls
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
            }
        }
        .aspectRatio(aspect, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    (service.isSelectionMode ? (cardIsSelected ? Color.accent : Color.primary.opacity(0.1)) :
                    (isActive ? Color.accent : (cardIsSelected ? Color.accent : Color.primary.opacity(0.1)))),
                    style: StrokeStyle(
                        lineWidth: (service.isSelectionMode ? (cardIsSelected ? 3 : 1) : (isActive ? 3 : (cardIsSelected ? 3 : 1))),
                        lineCap: .round,
                        dash: (!service.isSelectionMode && isActive) ? [6, 4] : []
                    )
                )
                .animation(.easeInOut(duration: 0.25), value: cardIsSelected)
                .animation(.easeInOut(duration: 0.25), value: isActive)
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }

    private var overlayControls: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    .black.opacity(0.55),
                    .black.opacity(0.15),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 70)
            .allowsHitTesting(false)
            
            VStack {
                HStack {
                    FavoriteButton(
                        isFavorite: service.isFavorite(wallpaper),
                        action: { service.toggleFavorite(wallpaper) }
                    )
                    
                    Spacer()
                    
                    if isActive && !isStillWallpaper {
                        VolumeSlider(
                            volume: $service.volume,
                            onVolumeChange: { newVolume in
                                service.chvol(newVolume)
                            }
                        )
                        .scaleEffect(0.85)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                    
                    Spacer()
                    
                    CardMenuButton(
                        isStillWallpaper: isStillWallpaper,
                        isMenuOpen: $isMenuOpen,
                        onRename: { isEditing = true },
                        onExportOriginal: { onExport(false) },
                        onExportCustom: { onExport(true) },
                        onDelete: onDelete
                    )
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Spacer()
                
                if !isActive {
                    if service.screenCount > 1 && !isStillWallpaper {
                        VStack(spacing: 6) {
                            if showScreenPicker {
                                HStack(spacing: 6) {
                                    Button(action: {
                                        showScreenPicker = false
                                        onSelect()
                                    }) {
                                        VStack(spacing: 3) {
                                            Image(systemName: "display.2")
                                                .font(.system(size: 13, weight: .medium))
                                            Text("All")
                                                .font(.system(size: 9, weight: .medium))
                                        }
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 36)
                                        .background {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(red: 0.42, green: 0.47, blue: 0.85).opacity(0.85))
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    ForEach(0..<service.screenCount, id: \.self) { idx in
                                        Button(action: {
                                            showScreenPicker = false
                                            service.set_wp_on_screen(wallpaper, screenIndex: idx)
                                        }) {
                                            VStack(spacing: 3) {
                                                Image(systemName: "display")
                                                    .font(.system(size: 13, weight: .medium))
                                                Text("\(idx + 1)")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            .foregroundStyle(.white)
                                            .frame(width: 36, height: 36)
                                            .background {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.white.opacity(0.15))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                                    }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                ))
                            } else {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showScreenPicker = true
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 13, weight: .medium))
                                        Text(NSLocalizedString("set_wallpaper", comment: "set wallpaper"))
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .semibold))
                                            .opacity(0.7)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.thinMaterial)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                                            }
                                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    }
                                    .scaleEffect(isHoveredSet ? 1.02 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        isHoveredSet = hovering
                                    }
                                }
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showScreenPicker)
                        .padding(.bottom, 12)
                    } else {
                        SimpleButton(
                            title: NSLocalizedString("set_wallpaper", comment: "set wallpaper"),
                            icon: "wand.and.stars",
                            isPrimary: true,
                            action: onSelect
                        )
                        .padding(.bottom, 12)
                    }
                }
            }
        }
    }
    
    private func loadAspectRatio() {
        let path = wallpaper.path
        if wallpaper.isFolder {
            aspect = 1.0
            return
        }
        if let cachedAspect = Self.aspectCache[path] {
            aspect = cachedAspect
            return
        }
        let ext = (path as NSString).pathExtension.lowercased()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var resolvedAspect: CGFloat?
            
            if ["gif", "jpg", "jpeg", "png"].contains(ext) {
                if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                   let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                   let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                   let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
                   height > 0 {
                    resolvedAspect = width / height
                }
            } else if ["mp4", "mov"].contains(ext) {
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                if let track = asset.tracks(withMediaType: .video).first {
                    let size = track.naturalSize.applying(track.preferredTransform)
                    let width = abs(size.width)
                    let height = abs(size.height)
                    if height > 0 {
                        resolvedAspect = width / height
                    }
                }
            }
            
            if let aspectVal = resolvedAspect {
                DispatchQueue.main.async {
                    Self.aspectCache[path] = aspectVal
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.aspect = aspectVal
                    }
                }
            }
        }
    }
}

struct WallpaperCardInfo: View {
    let wallpaper: endup_wp
    @Binding var isEditing: Bool
    let onRename: (String) -> Void
    
    @State private var editedName = ""
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        Group {
            if isEditing {
                HStack(spacing: 4) {
                    TextField("", text: $editedName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.9))
                        .focused($isNameFocused)
                        .onSubmit {
                            saveName()
                        }
                    
                    Button(action: saveName) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        isEditing = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.1))
                )
                .padding(.horizontal, 8)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(wallpaper.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.9))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.string(fromByteCount: wallpaper.fileSize, countStyle: .file))
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .layoutPriority(1)
                }
                .padding(.horizontal, 8)
            }
        }
        .onChange(of: isEditing) { editing in
            if editing {
                editedName = wallpaper.name
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isNameFocused = true
                }
            }
        }
    }
    
    private func saveName() {
        if !editedName.isEmpty && editedName != wallpaper.name {
            onRename(editedName)
        }
        isEditing = false
    }
}

// MARK: - Browse Wallpaper Card

struct BrowseWallpaperCard: View {
    @EnvironmentObject private var service: macpaperService
    let item: AnyWallpaper

    private var previewAspectRatio: CGFloat {
        let rawRatio = CGFloat(item.width) / CGFloat(max(1, item.height))
        guard rawRatio.isFinite, rawRatio > 0 else {
            return 16.0 / 9.0
        }
        return min(max(rawRatio, 0.65), 2.4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BrowseCardPreview(item: item, aspectRatio: previewAspectRatio)
                .frame(maxWidth: .infinity)
            BrowseCardInfo(id: item.id, width: item.width, height: item.height)
                .padding(.bottom, 6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let isDownloaded: Bool
            let localPath: String
            
            if let downloadURL = item.downloadURL {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let wpStorageDir = home.appendingPathComponent(".local/share/paper/wallpaper")
                let fileName = "\(item.id)-\(downloadURL.lastPathComponent)"
                let destinationURL = wpStorageDir.appendingPathComponent(fileName)
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    isDownloaded = true
                    localPath = destinationURL.path
                } else {
                    isDownloaded = false
                    localPath = downloadURL.absoluteString
                }
            } else {
                isDownloaded = false
                localPath = item.previewURL?.absoluteString ?? ""
            }
            
            let tempWp = endup_wp(
                id: UUID(),
                name: item.id,
                path: localPath,
                preview: item.previewURL?.absoluteString,
                createdDate: Date(),
                fileSize: 0
            )
            
            withAnimation(.easeInOut(duration: 0.3)) {
                service.previewWallpaper = tempWp
                service.showPreview = true
            }
        }
    }
}

// MARK: - BrowseCardPreview

private struct BrowseCardPreview: View {
    let item: AnyWallpaper
    let aspectRatio: CGFloat

    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var isHovered = false
    @State private var isDownloading = false
    @State private var isDownloaded = false
    @State private var downloadProgress: Double = 0
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var progressObservation: NSKeyValueObservation?
    @State private var imageTask: URLSessionDataTask?
    @State private var isDownloadButtonHovered = false

    var body: some View {
        // MARK: - Preview
        ZStack {
            Rectangle()
                .fill(Color.brown.opacity(0.2))
                .overlay {
                    if let image = image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if isLoading {
                        ProgressView()
                    }
                }
                .clipped()

            if item.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .background {
                        Circle()
                            .fill(.black.opacity(0.3))
                            .frame(width: 40, height: 40)
                    }
            }

            if isHovered {
                browseOverlay
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
            }

            if isDownloading {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.05, downloadProgress))
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.black.opacity(0.4)))
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadPreview()
        }
        .task {
            checkIfDownloaded()
        }
        .onDisappear {
            downloadTask?.cancel()
            progressObservation?.invalidate()
            imageTask?.cancel()
        }
    }

    // MARK: - Overlay

    private var browseOverlay: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    .black.opacity(0.55),
                    .black.opacity(0.15),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 70)
            .allowsHitTesting(false)

            VStack {
                HStack(alignment: .center, spacing: 8) {
                    if item.provider == .pexels, let author = item.authorName, let url = item.authorURL {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            Text("by \(author)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.black.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if isDownloaded {
                        DownloadedCheckButton()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer()
                
                if !isDownloaded && !isDownloading {
                    Button(action: {
                        downloadWallpaper()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 13, weight: .medium))
                            Text("Download")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                                }
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        .scaleEffect(isDownloadButtonHovered ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            isDownloadButtonHovered = hovering
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - Logic

    private func checkIfDownloaded() {
        guard let downloadURL = item.downloadURL else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let wpStorageDir = home.appendingPathComponent(".local/share/paper/wallpaper")
        let fileName = "\(item.id)-\(downloadURL.lastPathComponent)"
        let destinationURL = wpStorageDir.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            isDownloaded = true
        }
    }

    private func loadPreview() {
        guard let previewURL = item.previewURL else {
            isLoading = false
            return
        }

        let cacheKey = previewURL.absoluteString as NSString
        if let cachedImage = ThumbnailCache.shared.getImage(forKey: cacheKey as String) {
            self.image = cachedImage
            self.isLoading = false
            return
        }

        imageTask = URLSession.shared.dataTask(with: previewURL) { data, response, error in
            if let _ = error {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            let nsImage = Self.downsampleImage(data: data, targetWidth: 400) ?? NSImage(data: data)

            guard let nsImage = nsImage else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            ThumbnailCache.shared.setImage(nsImage, forKey: cacheKey as String)

            DispatchQueue.main.async {
                self.image = nsImage
                self.isLoading = false
            }
        }
        imageTask?.resume()
    }

    private func downloadWallpaper(retryCount: Int = 0) {
        guard let downloadURL = item.downloadURL else { return }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let wpStorageDir = home.appendingPathComponent(".local/share/paper/wallpaper")

        do {
            try FileManager.default.createDirectory(at: wpStorageDir, withIntermediateDirectories: true)

            let fileName = "\(item.id)-\(downloadURL.lastPathComponent)"
            let destinationURL = wpStorageDir.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                isDownloaded = true
                return
            }

            isDownloading = true
            downloadProgress = 0

            downloadTask = URLSession.shared.downloadTask(with: downloadURL) { tempURL, response, error in
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.progressObservation?.invalidate()
                    self.progressObservation = nil
                }

                if let _ = error {
                    if retryCount < 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.downloadWallpaper(retryCount: retryCount + 1)
                        }
                    }
                    return
                }

                guard let tempURL = tempURL else { return }

                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    DispatchQueue.main.async {
                        self.isDownloaded = true
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WallpaperDownloadCompleted"),
                            object: nil
                        )
                    }
                } catch { }
            }

            progressObservation = downloadTask?.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                }
            }

            downloadTask?.resume()

        } catch {
            isDownloading = false
            downloadProgress = 0
        }
    }

    // MARK: - Image Downsampling

    private static func downsampleImage(data: Data, targetWidth: CGFloat) -> NSImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let maxPixel = targetWidth * scale
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

// MARK: - BrowseCardInfo

private struct BrowseCardInfo: View {
    let id: String
    let width: Int
    let height: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(id)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
            Spacer()
            Text("\(width)×\(height)")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.8))
                .layoutPriority(1)
        }
        .padding(.horizontal, 8)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AccentButtonView(configuration: configuration)
    }
    
    private struct AccentButtonView: View {
        let configuration: Configuration
        @State private var isHovered = false
        
        var body: some View {
            configuration.label
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 200)
                        .fill(Color.accent)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 200)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                }
                .opacity(configuration.isPressed ? 0.85 : (isHovered ? 0.92 : 1.0))
                .scaleEffect(configuration.isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
        }
    }
}

struct MaterialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MaterialButtonView(configuration: configuration)
    }
    
    private struct MaterialButtonView: View {
        let configuration: Configuration
        @State private var isHovered = false
        
        var body: some View {
            configuration.label
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(.black.opacity(0.2))
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
                .opacity(configuration.isPressed ? 0.85 : (isHovered ? 0.92 : 1.0))
                .scaleEffect(configuration.isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
        }
    }
}
