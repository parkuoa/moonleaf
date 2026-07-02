//
//  ManagerApp.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers
import ImageIO

class MenuHandler: NSObject {
    weak var service: macpaperService?
    
    @objc func toggleVideos() {
        guard let service = service else { return }
        service.showVideos.toggle()
        service.fetch_wallpapers()
        print("toggle videos: \(service.showVideos)")
    }
    
    @objc func toggleImages() {
        guard let service = service else { return }
        service.showImages.toggle()
        service.fetch_wallpapers()
        print("toggle images: \(service.showImages)")
    }
}

struct ManagerView: View {
    @EnvironmentObject private var service: macpaperService
    @State private var show_importer = false
    @State private var importingFolder = false
    @State private var showAddPopover = false
    @State private var file_drag = false
    @State private var show_wp_util_overlay = false
    @State private var overlay_chosen_wp: endup_wp? = nil
    @State private var showWpActionsDropdown = false
    @State private var isSelectHovered = false
    private let menuHandler = MenuHandler()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                let width = geo.size.width
                let spacing: CGFloat = 20
                let columnCount = max(2, Int((width - 48) / (260 + spacing)))
                let colWidth = (width - 48 - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
                let displayed = service.showFavoritesOnly
                    ? service.wallpapers.filter { service.isFavorite($0) }
                    : service.wallpapers

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 48)

                        if service.isAtRoot {
                            toolbarView
                        } else {
                            HStack {
                                Button(action: { service.back() }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.left")
                                        Text("Back")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.1)))
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 32)
                                .padding(.top, 16)
                                
                                Spacer()
                            }
                        }

                        ZStack {
                            if service.isLoading {
                                loadingView
                                    .frame(minHeight: max(200, geo.size.height - 120))
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                                        removal: .opacity.combined(with: .scale(scale: 1.1))
                                    ))
                            } else if service.wallpapers.isEmpty {
                                NoWpView
                                    .frame(minHeight: max(200, geo.size.height - 120))
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                        removal: .opacity
                                    ))
                            } else {
                                LazyLibraryMasonryContent(
                                    wallpapers: displayed,
                                    columnCount: columnCount,
                                    spacing: spacing,
                                    colWidth: colWidth,
                                    onSelect: { wallpaper in
                                        withAnimation(.easeInOut(duration: 0.3)) { service.set_wp(wallpaper) }
                                    },
                                    onTap: { wallpaper in
                                        if wallpaper.isFolder {
                                            service.navigateTo(folder: wallpaper)
                                        } else {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                service.previewWallpaper = wallpaper
                                                service.showPreview = true
                                            }
                                        }
                                    },
                                    onDelete: { wallpaper in
                                        withAnimation(.easeInOut(duration: 0.4)) {
                                            delete_wp(wallpaper)
                                            if service.selected_wp?.id == wallpaper.id { service.select_wp(nil) }
                                        }
                                    },
                                    onRename: { wallpaper, name in rename_wp(wallpaper, to: name) },
                                    onExport: { wallpaper, custom in export_wp(wallpaper, custom: custom) },
                                    onQuickPreview: { wallpaper in
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            service.previewWallpaper = wallpaper
                                            service.showPreview = true
                                        }
                                    }
                                )
                                .padding(.horizontal, 24)
                                .padding(.bottom, 32)
                                .padding(.top, 8)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                ))
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $file_drag) { providers in
                drop_handle(providers)
            }
            .animation(.easeInOut(duration: 0.4), value: service.isLoading)
            .animation(.easeInOut(duration: 0.4), value: service.wallpapers.isEmpty)

            if show_wp_util_overlay && !service.isSelectionMode, let wallpaper = overlay_chosen_wp {
                WPCUtilOverlay(
                    wallpaper: wallpaper,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            service.select_wp(nil)
                            show_wp_util_overlay = false
                            overlay_chosen_wp = nil
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }

            if service.isSelectionMode {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Text("\(service.selectedWallpapers.count) items selected")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Divider().frame(height: 24).background(Color.white.opacity(0.2))
                        
                        // Favorite button
                        Button(action: {
                            toggleFavoriteForSelected()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Favorite")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                        .buttonStyle(MaterialButtonStyle())
                        .disabled(service.selectedWallpapers.isEmpty)
                        
                        Divider().frame(height: 24).background(Color.white.opacity(0.2))
                        
                        // Delete button
                        Button(action: {
                            deleteSelected()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Delete")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                        .buttonStyle(MaterialButtonStyle())
                        .disabled(service.selectedWallpapers.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .onAppear {
            service.fetch_wallpapers()
            menuHandler.service = service
            service.isSelectionMode = false
            service.selectedWallpapers.removeAll()
        }
        .onChange(of: service.selected_wp) { selected in
            withAnimation(.easeInOut(duration: 0.3)) {
                show_wp_util_overlay = selected != nil
                overlay_chosen_wp = selected
            }
        }

        .fileImporter(
            isPresented: $show_importer,
            allowedContentTypes: importingFolder ? [.folder] : [.movie, .image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if importingFolder {
                        import_folder(from: url)
                    } else {
                        import_wp(from: url)
                    }
                }
            case .failure(let error):
                print("import error: \(error)")
            }
        }
    }
    
    private var toolbarView: some View {
        HStack {
            Text("Library")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                // Select / Cancel button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        service.isSelectionMode.toggle()
                        if service.isSelectionMode {
                            service.select_wp(nil)
                        } else {
                            service.selectedWallpapers.removeAll()
                        }
                    }
                }) {
                    Text(service.isSelectionMode ? "Cancel" : "Select")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(service.isSelectionMode ? Color.red : Color.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule()
                                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                }
                        }
                }
                .buttonStyle(.plain)
                .scaleEffect(isSelectHovered ? 1.02 : 1.0)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isSelectHovered = hovering
                    }
                }
                .help(service.isSelectionMode ? "Cancel Selection" : "Select Wallpapers")

                // Add button
                Button(action: { showAddPopover.toggle() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .padding(8)
                        .background {
                            Circle()
                                .fill(Color.accent)
                        }
                }
                .buttonStyle(.plain)
            }
            .popover(isPresented: $showAddPopover, arrowEdge: .bottom) {
                VStack(spacing: 4) {
                    Button(action: {
                        importingFolder = false
                        showAddPopover = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            show_importer = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text("file")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.001)))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        importingFolder = true
                        showAddPopover = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            show_importer = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                            Text("folder")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.001)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .frame(width: 160)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
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

    private func showFilterMenu() {
        let menu = NSMenu()
        
        let filterHeader = NSMenuItem(
            title: NSLocalizedString("show_types", comment: "Show"),
            action: nil,
            keyEquivalent: ""
        )
        filterHeader.isEnabled = false
        menu.addItem(filterHeader)
        
        let videoItem = NSMenuItem(
            title: NSLocalizedString("show_videos", comment: "Videos"),
            action: #selector(MenuHandler.toggleVideos),
            keyEquivalent: ""
        )
        videoItem.target = menuHandler
        videoItem.state = service.showVideos ? .on : .off
        menu.addItem(videoItem)
        
        let imageItem = NSMenuItem(
            title: NSLocalizedString("show_images", comment: "Images"),
            action: #selector(MenuHandler.toggleImages),
            keyEquivalent: ""
        )
        imageItem.target = menuHandler
        imageItem.state = service.showImages ? .on : .off
        menu.addItem(imageItem)
        
        if let window = NSApp.keyWindow,
           let contentView = window.contentView {
            
            let filterButtonTitle = NSLocalizedString("filter", comment: "Filter")
            if let filterButton = findButton(with: filterButtonTitle, in: contentView) {
                let buttonFrame = filterButton.convert(filterButton.bounds, to: nil)
                let menuPosition = NSPoint(x: buttonFrame.minX, y: buttonFrame.maxY)
                menu.popUp(positioning: nil, at: menuPosition, in: nil)
            } else {
                menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            }
        }
    }

    private func findButton(with title: String, in view: NSView) -> NSButton? {
        for subview in view.subviews {
            if let button = subview as? NSButton, button.title == title {
                return button
            }
            if let foundButton = findButton(with: title, in: subview) {
                return foundButton
            }
        }
        return nil
    }
    

    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Circle()
                            .stroke(.primary.opacity(0.1), lineWidth: 1)
                    }
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primary.opacity(0.7)))
                    .scaleEffect(1.2)
            }
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("loading_wallpapers", comment: "loading wallpapers"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                
                Text(NSLocalizedString("scanning_files", comment: "scanning for video files"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var NoWpView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.primary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("no_wallpapers_found", comment: "no wallpapers found"))
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                
                Text(NSLocalizedString("drop_files_or_add", comment: "drop files or add wallpaper"))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("supported_formats", comment: "supported file formats"))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .onDrop(of: [.fileURL, .directory], isTargeted: $file_drag) { providers in
            drop_handle(providers)
        }
    }
    

    
    private func drop_handle(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    import_wp(from: url)
                }
            }
            return true
        }
        return false
    }
    
    private func import_wp(from url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ["mp4", "mov", "gif", "jpg", "jpeg", "png"].contains(ext) else { return }
        
        let wp_storage_dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/paper/wallpaper")
        
        do {
            try FileManager.default.createDirectory(at: wp_storage_dir, withIntermediateDirectories: true)
            let destination = wp_storage_dir.appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            
            if service.importMethod == .link {
                try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: url.resolvingSymlinksInPath())
            } else {
                try FileManager.default.copyItem(at: url, to: destination)
            }
            service.fetch_wallpapers()
        } catch { print(error) }
    }
    
    private func import_folder(from url: URL) {
        let wp_storage_dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/paper/wallpaper")
        
        do {
            try FileManager.default.createDirectory(at: wp_storage_dir, withIntermediateDirectories: true)
            let destination = wp_storage_dir.appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            
            if service.importMethod == .link {
                try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: url.resolvingSymlinksInPath())
            } else {
                try FileManager.default.copyItem(at: url, to: destination)
            }
            service.fetch_wallpapers()
        } catch { print(error) }
    }
    
    private func delete_wp(_ wallpaper: endup_wp) {
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: wallpaper.path), resultingItemURL: nil)
            service.fetch_wallpapers()
        } catch {
            print("while deleting wallpaper: \(error)")
        }
    }
    
    private func rename_wp(_ wallpaper: endup_wp, to newName: String) {
        let fileURL = URL(fileURLWithPath: wallpaper.path)
        let directory = fileURL.deletingLastPathComponent()
        let fileExtension = fileURL.pathExtension
        let newFileName = "\(newName).\(fileExtension)"
        let newURL = directory.appendingPathComponent(newFileName)
        
        do {
            try FileManager.default.moveItem(at: fileURL, to: newURL)
            service.fetch_wallpapers()
        } catch {
            print("Error renaming file: \(error)")
        }
    }

    private func toggleFavoriteForSelected() {
        let selectedWps = service.wallpapers.filter { service.selectedWallpapers.contains($0.id) }
        let allAreFavorites = selectedWps.allSatisfy { service.isFavorite($0) }
        
        for wp in selectedWps {
            let isFav = service.isFavorite(wp)
            if allAreFavorites {
                if isFav {
                    service.toggleFavorite(wp)
                }
            } else {
                if !isFav {
                    service.toggleFavorite(wp)
                }
            }
        }
        
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        appDelegate?.update_sb_menu()
    }
    
    private func deleteSelected() {
        let selectedWps = service.wallpapers.filter { service.selectedWallpapers.contains($0.id) }
        for wp in selectedWps {
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: wp.path), resultingItemURL: nil)
            } catch {
                print("Error trashing \(wp.name): \(error)")
            }
        }
        service.selectedWallpapers.removeAll()
        service.isSelectionMode = false
        service.fetch_wallpapers()
        
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        appDelegate?.update_sb_menu()
    }
    
    private func export_wp(_ wallpaper: endup_wp, custom: Bool = false) {
        let sourceURL = URL(fileURLWithPath: wallpaper.path)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        
        let fileExtension = sourceURL.pathExtension.lowercased()
        let isImage = ["jpg", "jpeg", "png", "gif"].contains(fileExtension)
        
        if isImage && custom {
            if let image = NSImage(contentsOf: sourceURL) {
                self.showCropEditorWindow(image: image, wallpaper: wallpaper, sourceURL: sourceURL)
            }
        } else {
            ExportManager.shared.exportOriginal(wallpaper: wallpaper, sourceURL: sourceURL)
        }
    }
    
    private func showCropEditorWindow(image: NSImage, wallpaper: endup_wp, sourceURL: URL) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let cropView = CropEditorView(
            image: image,
            wallpaperName: wallpaper.name,
            onCrop: { [weak window] cropRect, targetSize in
                window?.close()
                ExportManager.shared.exportWithCrop(
                    wallpaper: wallpaper,
                    sourceURL: sourceURL,
                    cropRect: cropRect,
                    targetSize: targetSize
                )
            },
            onCancel: { [weak window] in
                window?.close()
            }
        )
        
        window.center()
        window.title = NSLocalizedString("crop_editor_title", comment: "Crop Image")
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: cropView)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func isStillWallpaper(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png"].contains(ext)
    }
}

private struct LazyLibraryMasonryContent: View {
    let wallpapers: [endup_wp]
    let columnCount: Int
    let spacing: CGFloat
    let colWidth: CGFloat
    
    let onSelect: (endup_wp) -> Void
    let onTap: (endup_wp) -> Void
    let onDelete: (endup_wp) -> Void
    let onRename: (endup_wp, String) -> Void
    let onExport: (endup_wp, Bool) -> Void
    let onQuickPreview: (endup_wp) -> Void
    
    @EnvironmentObject private var service: macpaperService

    private var columns: [[endup_wp]] {
        guard columnCount > 0 else { return [] }
        var cols = Array(repeating: [endup_wp](), count: columnCount)
        var heights = Array(repeating: CGFloat(0), count: columnCount)

        for item in wallpapers {
            let shortest = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            cols[shortest].append(item)
            let aspect: CGFloat = item.isFolder ? 1.0 : 1.5
            heights[shortest] += 1.0 / aspect
        }

        return cols
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columnCount, id: \.self) { colIndex in
                LazyVStack(spacing: spacing) {
                    if colIndex < columns.count {
                        ForEach(columns[colIndex]) { wallpaper in
                            WallpaperCard(
                                wallpaper: wallpaper,
                                isActive: service.current_wp == wallpaper.path,
                                cardIsSelected: service.isSelectionMode ? service.selectedWallpapers.contains(wallpaper.id) : (service.selected_wp?.id == wallpaper.id),
                                onSelect: { onSelect(wallpaper) },
                                onTap: { onTap(wallpaper) },
                                onDelete: { onDelete(wallpaper) },
                                onRename: { onRename(wallpaper, $0) },
                                onExport: { onExport(wallpaper, $0) },
                                onQuickPreview: { onQuickPreview(wallpaper) }
                            )
                            .environmentObject(service)
                        }
                    }
                }
                .frame(width: colWidth)
            }
        }
    }
}

struct videoPreview: View {
    let videoURL: URL
    @State private var thumbnail: NSImage?
    
    private static var thumbnailCache = NSCache<NSString, NSImage>()
    private static var loadingOperations = [String: Operation]()
    private static let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .utility
        return queue
    }()
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(Color.brown.opacity(0.3))
                    .overlay {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                            .scaleEffect(0.8)
                    }
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            cancelLoading()
        }
    }

    private func loadThumbnail() {
        let cacheKey = videoURL.path as NSString
        
        if let cachedThumbnail = Self.thumbnailCache.object(forKey: cacheKey) {
            self.thumbnail = cachedThumbnail
            return
        }
        
        cancelLoading()
        
        var operation: BlockOperation?
        
        operation = BlockOperation {
            if operation?.isCancelled ?? true { return }
            
            let asset = AVAsset(url: self.videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 300, height: 200)
            imageGenerator.requestedTimeToleranceAfter = .zero
            imageGenerator.requestedTimeToleranceBefore = .zero
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 60), actualTime: nil)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                
                if operation?.isCancelled ?? true { return }
                
                Self.thumbnailCache.setObject(nsImage, forKey: cacheKey)
                
                DispatchQueue.main.async {
                    Self.loadingOperations.removeValue(forKey: self.videoURL.path)
                    if let op = operation, !op.isCancelled {
                        self.thumbnail = nsImage
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    Self.loadingOperations.removeValue(forKey: self.videoURL.path)
                }
            }
        }
        
        if let op = operation {
            Self.loadingOperations[videoURL.path] = op
            Self.operationQueue.addOperation(op)
        }
    }

    private func cancelLoading() {
        if let operation = Self.loadingOperations[videoURL.path] {
            operation.cancel()
            Self.loadingOperations.removeValue(forKey: videoURL.path)
        }
    }
}

struct SimpleButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        RippleButton(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
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
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct VolumeSlider: View {
    @Binding var volume: Double
    let onVolumeChange: (Double) -> Void
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : (volume < 0.33 ? "speaker.fill" : (volume < 0.67 ? "speaker.wave.1.fill" : "speaker.wave.2.fill")))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
                .frame(width: 16)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.regularMaterial.opacity(0.6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [
                                Color.primary.opacity(0.8),
                                Color.primary.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * volume, height: 12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(isDragging ? 0.3 : 0.2))
                        }
                    
                    Circle()
                        .fill(.regularMaterial)
                        .overlay {
                            Circle()
                                .fill(.white.opacity(0.9))
                                .scaleEffect(0.7)
                        }
                        .overlay {
                            Circle()
                                .stroke(.primary.opacity(0.2), lineWidth: 1)
                        }
                        .frame(width: isDragging ? 18 : 16, height: isDragging ? 18 : 16)
                        .position(
                            x: max(8, min(geometry.size.width - 8, geometry.size.width * volume)),
                            y: geometry.size.height / 2
                        )
                        .scaleEffect(isHovered || isDragging ? 1.1 : 1.0)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isDragging = true
                                }
                            }
                            
                            let newVolume = max(0, min(1, value.location.x / geometry.size.width))
                            volume = newVolume
                            
                            let now = Date()
                            if now.timeIntervalSince(lastUpdateTime) > 0.02 {
                                lastUpdateTime = now
                                onVolumeChange(newVolume)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDragging = false
                            }
                            onVolumeChange(volume)
                        }
                )
            }
            .frame(width: 80, height: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.primary.opacity(0.2), lineWidth: 1)
                }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


struct LazyImagePreview: View {
    let path: String
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.brown.opacity(0.3))
                    .onAppear {
                        loadThumbnail()
                    }
            }
        }
    }
    
    private func loadThumbnail() {
        if let cachedImage = ImageCache.shared.getImage(forKey: path) {
            self.image = cachedImage
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        DispatchQueue.global(qos: .utility).async {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions as CFDictionary) else {
                if let fullImage = NSImage(contentsOfFile: self.path) {
                    let thumbnail = self.resizeToFillLegacy(fullImage)
                    ImageCache.shared.setImage(thumbnail, forKey: self.path)
                    DispatchQueue.main.async {
                        self.image = thumbnail
                    }
                }
                return
            }
            
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let maxPixel = 300.0 * scale
            let downsampleOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
                if let fullImage = NSImage(contentsOfFile: self.path) {
                    let thumbnail = self.resizeToFillLegacy(fullImage)
                    ImageCache.shared.setImage(thumbnail, forKey: self.path)
                    DispatchQueue.main.async {
                        self.image = thumbnail
                    }
                }
                return
            }
            
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            ImageCache.shared.setImage(thumbnail, forKey: self.path)
            DispatchQueue.main.async {
                self.image = thumbnail
            }
        }
    }
    
    private func resizeToFillLegacy(_ fullImage: NSImage) -> NSImage {
        let maxDimension: CGFloat = 300
        let origSize = fullImage.size
        let ratio = origSize.width / origSize.height
        let targetSize: NSSize
        if ratio > 1 {
            targetSize = NSSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            targetSize = NSSize(width: maxDimension * ratio, height: maxDimension)
        }
        return self.resizeImageToFill(fullImage, to: targetSize)
    }
    
    private func resizeImageToFill(_ image: NSImage, to size: NSSize) -> NSImage {
        let imageSize = image.size
        let widthRatio  = size.width / imageSize.width
        let heightRatio = size.height / imageSize.height
        
        let scaleRatio = max(widthRatio, heightRatio)
        
        let scaledSize = NSSize(
            width: imageSize.width * scaleRatio,
            height: imageSize.height * scaleRatio
        )
        
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        let drawingRect = NSRect(
            x: (size.width - scaledSize.width) / 2,
            y: (size.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        image.draw(in: drawingRect,
                  from: NSRect(origin: .zero, size: imageSize),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

struct WPCUtilOverlay: View {
    let wallpaper: endup_wp
    let onClose: () -> Void
    
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage? = nil
    
    var body: some View {
        HStack(spacing: 20) {
            Group {
                let ext = (wallpaper.path as NSString).pathExtension.lowercased()
                
                if ["gif", "jpg", "jpeg", "png"].contains(ext) {
                    LazyImagePreview(path: wallpaper.path)
                        .id(wallpaper.id)
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if ["mp4", "mov"].contains(ext) {
                    videoPreview(videoURL: URL(fileURLWithPath: wallpaper.path))
                        .id(wallpaper.id)
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .transition(.opacity)

            VStack(alignment: .leading, spacing: 4) {
                Text(wallpaper.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(ByteCountFormatter.string(fromByteCount: wallpaper.fileSize, countStyle: .file))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(.regularMaterial)
                            .overlay {
                                Circle()
                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(width: 300)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .padding(.bottom, 20)
        .transition(.opacity)
    }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 30
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    func getImage(forKey key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: NSImage, forKey key: String) {
        let cost = image.size.width * image.size.height * 4
        cache.setObject(image, forKey: key as NSString, cost: Int(cost))
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

struct CropEditorView: View {
    let image: NSImage
    let wallpaperName: String
    let onCrop: (CGRect, CGSize) -> Void
    let onCancel: () -> Void
    
    @State private var selectedRatioIndex: Int = 0
    @State private var imageSize: CGSize = .zero
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    
    struct RatioOption: Identifiable {
        let id: String
        let name: String
        let size: CGSize
        var aspectRatio: CGFloat { size.width / size.height }
    }
    
    private let ratios: [RatioOption] = [
        RatioOption(id: "iphone15promax", name: "iPhone 15 Pro Max", size: CGSize(width: 1290, height: 2796)),
        RatioOption(id: "iphone15pro", name: "iPhone 15 Pro", size: CGSize(width: 1179, height: 2556)),
        RatioOption(id: "iphone14pro", name: "iPhone 14 Pro", size: CGSize(width: 1179, height: 2556)),
        RatioOption(id: "iphone13pro", name: "iPhone 13 Pro", size: CGSize(width: 1170, height: 2532)),
        RatioOption(id: "iphonese", name: "iPhone SE", size: CGSize(width: 750, height: 1334)),
        RatioOption(id: "ipadpro12", name: "iPad Pro 12.9\"", size: CGSize(width: 2732, height: 2048)),
        RatioOption(id: "ipadpro11", name: "iPad Pro 11\"", size: CGSize(width: 2388, height: 1668)),
        RatioOption(id: "4k", name: "4K UHD (3840×2160)", size: CGSize(width: 3840, height: 2160)),
        RatioOption(id: "1440p", name: "1440p (2560×1440)", size: CGSize(width: 2560, height: 1440)),
        RatioOption(id: "1080p", name: "1080p (1920×1080)", size: CGSize(width: 1920, height: 1080)),
        RatioOption(id: "ultrawide", name: "Ultrawide 21:9", size: CGSize(width: 3440, height: 1440))
    ]
    
    private var selectedRatio: RatioOption { ratios[selectedRatioIndex] }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                headerView
                cropCanvas
                controlsView
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            ratioSidebar
                .frame(width: 220)
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            loadImageSize()
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("crop_editor_title", comment: "Crop Image"))
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.mainSurface)
    }
    
    private var cropCanvas: some View {
        GeometryReader { geo in
            let canvasSize = geo.size
            let cropFrameSize = calculateCropFrameSize(in: canvasSize)
            let imageDisplaySize = calculateImageDisplaySize(for: cropFrameSize)
            let clampedOffset = clampOffset(imageSize: imageDisplaySize, cropSize: cropFrameSize)
            
            ZStack {
                Color(NSColor.darkGray).opacity(0.3)
                
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
                        .offset(clampedOffset)
                }
                .frame(width: cropFrameSize.width, height: cropFrameSize.height)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .overlay(cropGridOverlay(size: cropFrameSize))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newOffset = CGSize(
                                width: lastPanOffset.width + value.translation.width,
                                height: lastPanOffset.height + value.translation.height
                            )
                            panOffset = newOffset
                        }
                        .onEnded { _ in
                            lastPanOffset = clampOffset(imageSize: imageDisplaySize, cropSize: cropFrameSize)
                            panOffset = lastPanOffset
                        }
                )
                
                VStack {
                    Spacer()
                    HStack {
                        Text("\(Int(selectedRatio.size.width)) × \(Int(selectedRatio.size.height))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                    .padding(.bottom, 8)
                }
                .frame(width: cropFrameSize.width, height: cropFrameSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
    }
    
    private func cropGridOverlay(size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width / 3, y: 0))
                path.addLine(to: CGPoint(x: size.width / 3, y: size.height))
                path.move(to: CGPoint(x: size.width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: size.width * 2 / 3, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height / 3))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 3))
                path.move(to: CGPoint(x: 0, y: size.height * 2 / 3))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 2 / 3))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text(NSLocalizedString("crop_zoom", comment: "Zoom"))
                    .font(.system(size: 12))
                    .frame(width: 40, alignment: .leading)
                
                Slider(value: $zoomScale, in: 1.0...3.0, step: 0.1)
                    .frame(maxWidth: 300)
                
                Text(String(format: "%.1fx", zoomScale))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(width: 40)
                
                Button(action: resetCrop) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text(NSLocalizedString("browse_cancel", comment: "Cancel"))
                        .frame(width: 100)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
                
                Button(action: performCrop) {
                    Text(NSLocalizedString("crop_apply", comment: "Apply"))
                        .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .background(Color.mainSurface)
    }
    
    private var ratioSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("export_aspect_ratio", comment: "Aspect Ratio"))
                .font(.system(size: 13, weight: .semibold))
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader("iPhone")
                    ForEach(0..<5) { i in
                        ratioRow(index: i)
                    }
                    
                    sectionHeader("iPad")
                    ForEach(5..<7) { i in
                        ratioRow(index: i)
                    }
                    
                    sectionHeader("Desktop")
                    ForEach(7..<ratios.count) { i in
                        ratioRow(index: i)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color.secondarySurface)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
    
    private func ratioRow(index: Int) -> some View {
        let ratio = ratios[index]
        let isSelected = selectedRatioIndex == index
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedRatioIndex = index
                resetCrop()
            }
        }) {
            HStack {
                Text(ratio.name)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    private func loadImageSize() {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        }
    }
    
    private func calculateCropFrameSize(in canvasSize: CGSize) -> CGSize {
        let targetRatio = selectedRatio.aspectRatio
        let maxWidth = canvasSize.width * 0.85
        let maxHeight = canvasSize.height * 0.85
        
        var width: CGFloat
        var height: CGFloat
        
        if maxWidth / maxHeight > targetRatio {
            height = maxHeight
            width = height * targetRatio
        } else {
            width = maxWidth
            height = width / targetRatio
        }
        
        return CGSize(width: width, height: height)
    }
    
    private func calculateImageDisplaySize(for cropSize: CGSize) -> CGSize {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return cropSize
        }
        
        let imageRatio = imageSize.width / imageSize.height
        let cropRatio = cropSize.width / cropSize.height
        
        var baseWidth: CGFloat
        var baseHeight: CGFloat
        
        if imageRatio > cropRatio {
            baseHeight = cropSize.height
            baseWidth = baseHeight * imageRatio
        } else {
            baseWidth = cropSize.width
            baseHeight = baseWidth / imageRatio
        }
        
        return CGSize(width: baseWidth * zoomScale, height: baseHeight * zoomScale)
    }
    
    private func clampOffset(imageSize: CGSize, cropSize: CGSize) -> CGSize {
        let maxX = max(0, (imageSize.width - cropSize.width) / 2)
        let maxY = max(0, (imageSize.height - cropSize.height) / 2)
        
        return CGSize(
            width: min(maxX, max(-maxX, panOffset.width)),
            height: min(maxY, max(-maxY, panOffset.height))
        )
    }
    
    private func resetCrop() {
        panOffset = .zero
        lastPanOffset = .zero
        zoomScale = 1.0
    }
    
    private func performCrop() {
        guard imageSize.width > 0 && imageSize.height > 0 else { return }
        
        let targetRatio = selectedRatio.aspectRatio
        let imageRatio = imageSize.width / imageSize.height
        
        var baseCropWidth: CGFloat
        var baseCropHeight: CGFloat
        
        if imageRatio > targetRatio {
            baseCropHeight = imageSize.height
            baseCropWidth = baseCropHeight * targetRatio
        } else {
            baseCropWidth = imageSize.width
            baseCropHeight = baseCropWidth / targetRatio
        }
        
        let cropWidth = baseCropWidth / zoomScale
        let cropHeight = baseCropHeight / zoomScale
        
        let imageDisplaySize = CGSize(
            width: imageRatio > targetRatio ? imageSize.height * targetRatio * zoomScale : imageSize.width * zoomScale,
            height: imageRatio > targetRatio ? imageSize.height * zoomScale : imageSize.width / targetRatio * zoomScale
        )
        
        let normalizedOffsetX = -panOffset.width / imageDisplaySize.width
        let normalizedOffsetY = -panOffset.height / imageDisplaySize.height
        
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        
        let cropCenterX = centerX + normalizedOffsetX * imageSize.width
        let cropCenterY = centerY + normalizedOffsetY * imageSize.height
        
        var cropX = cropCenterX - cropWidth / 2
        var cropY = cropCenterY - cropHeight / 2
        
        cropX = max(0, min(imageSize.width - cropWidth, cropX))
        cropY = max(0, min(imageSize.height - cropHeight, cropY))
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        onCrop(cropRect, selectedRatio.size)
    }
}


class ExportManager: NSObject {
    static let shared = ExportManager()
    
    private var currentWallpaper: endup_wp?
    private var currentSourceURL: URL?
    private var onShowCropEditor: ((NSImage, endup_wp, URL) -> Void)?
    
    private let exportFolderFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/macpaper/export_folder")
    
    private override init() {
        super.init()
    }
    
    private func getExportFolder() -> URL {
        if FileManager.default.fileExists(atPath: exportFolderFile.path) {
            do {
                let path = try String(contentsOf: exportFolderFile).trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
            } catch {}
        }
        
        if let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            return picturesURL
        }
        
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    func showExportMenu(
        for wallpaper: endup_wp,
        sourceURL: URL,
        showCropEditor: @escaping (NSImage, endup_wp, URL) -> Void
    ) {
        self.currentWallpaper = wallpaper
        self.currentSourceURL = sourceURL
        self.onShowCropEditor = showCropEditor
        
        let menu = NSMenu()
        
        let originalItem = NSMenuItem(
            title: NSLocalizedString("export_original", comment: "Original Size"),
            action: #selector(handleExportOriginal),
            keyEquivalent: ""
        )
        originalItem.target = self
        menu.addItem(originalItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let customItem = NSMenuItem(
            title: NSLocalizedString("download_custom_ratio", comment: "Custom Aspect Ratio"),
            action: #selector(handleExportCustom),
            keyEquivalent: ""
        )
        customItem.target = self
        menu.addItem(customItem)
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func handleExportOriginal() {
        guard let wallpaper = currentWallpaper, let sourceURL = currentSourceURL else { return }
        exportOriginal(wallpaper: wallpaper, sourceURL: sourceURL)
    }
    
    @objc private func handleExportCustom() {
        guard let wallpaper = currentWallpaper,
              let sourceURL = currentSourceURL,
              let showCropEditor = onShowCropEditor,
              let image = NSImage(contentsOfFile: sourceURL.path) else { return }
        showCropEditor(image, wallpaper, sourceURL)
    }
    
    func exportOriginal(wallpaper: endup_wp, sourceURL: URL) {
        let fileExtension = sourceURL.pathExtension.lowercased()
        var allowedTypes: [UTType] = []
        
        switch fileExtension {
        case "jpg", "jpeg": allowedTypes = [.jpeg]
        case "png": allowedTypes = [.png]
        case "gif": allowedTypes = [.gif]
        case "mp4": allowedTypes = [.mpeg4Movie]
        case "mov": allowedTypes = [.quickTimeMovie]
        default: allowedTypes = [.jpeg, .png, .gif, .mpeg4Movie, .quickTimeMovie]
        }
        
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = allowedTypes
        savePanel.nameFieldStringValue = wallpaper.name
        savePanel.title = NSLocalizedString("export_wallpaper", comment: "Export Wallpaper")
        savePanel.directoryURL = getExportFolder()
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                } catch {
                    self.showError(error.localizedDescription)
                }
            }
            
            if previousPolicy == .accessory && NSApp.windows.filter({ $0.isVisible }).isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    func exportWithCrop(wallpaper: endup_wp, sourceURL: URL, cropRect: CGRect, targetSize: NSSize) {
        guard let sourceImage = NSImage(contentsOfFile: sourceURL.path) else { return }
        
        let croppedImage = cropImage(sourceImage, cropRect: cropRect, targetSize: targetSize)
        
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "\(wallpaper.name)_\(Int(targetSize.width))x\(Int(targetSize.height))"
        savePanel.title = NSLocalizedString("export_wallpaper", comment: "Export Wallpaper")
        savePanel.directoryURL = getExportFolder()
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                self.saveCroppedImage(croppedImage, to: destinationURL)
            }
            
            if previousPolicy == .accessory && NSApp.windows.filter({ $0.isVisible }).isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    private func cropImage(_ image: NSImage, cropRect: CGRect, targetSize: NSSize) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let croppedCGImage = cgImage.cropping(to: cropRect),
              let context = CGContext(
                  data: nil,
                  width: Int(targetSize.width),
                  height: Int(targetSize.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }
        
        context.interpolationQuality = .high
        context.draw(croppedCGImage, in: CGRect(origin: .zero, size: targetSize))
        
        guard let finalCGImage = context.makeImage() else { return image }
        return NSImage(cgImage: finalCGImage, size: targetSize)
    }
    
    private func saveCroppedImage(_ image: NSImage, to destinationURL: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            showError("Could not convert image")
            return
        }
        
        let fileExtension = destinationURL.pathExtension.lowercased()
        let imageData = fileExtension == "png"
            ? bitmapImage.representation(using: .png, properties: [:])
            : bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.95])
        
        guard let data = imageData else {
            showError("Could not create image data")
            return
        }
        
        do {
            try data.write(to: destinationURL)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("export_error", comment: "Export Error")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
