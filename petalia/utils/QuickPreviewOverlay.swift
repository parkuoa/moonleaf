//
//  QuickPreviewOverlay.swift
//  moonleaf
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI
import AVKit

struct QuickPreviewOverlay: View {
    let wallpaper: endup_wp
    let onClose: () -> Void
    
    enum ContentModeOption: String, CaseIterable, Identifiable {
        case fit = "Fit"
        case fill = "Fill"
        case stretch = "Stretch"
        
        var id: String { self.rawValue }
    }
    
    @State private var scalingOption: ContentModeOption = .fit
    @State private var isHovered = false
    @State private var currentTime = Date()
    @State private var isVisible = false
    @State private var player: AVPlayer?
    @State private var isVideoPlaying = true
    @State private var loadedImage: NSImage?
    @State private var isImageLoading = false
    @State private var imageLoadFailed = false
    @Namespace private var tabAnimation
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var progressObservation: NSKeyValueObservation?
    @EnvironmentObject private var service: macpaperService
    
    @AppStorage("clockFontSize") private var clockFontSize: Double = 120.0
    @AppStorage("clockFontDesign") private var clockFontDesign: String = "rounded"
    @AppStorage("clockFontWeight") private var clockFontWeight: String = "semibold"
    @AppStorage("clockColorType") private var clockColorType: String = "white"
    @AppStorage("clockCustomColorHex") private var clockCustomColorHex: String = "#FFFFFF"
    
    @State private var showEditPanel = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var fileExtension: String {
        if wallpaper.path.hasPrefix("/") {
            return (wallpaper.path as NSString).pathExtension.lowercased()
        } else if let url = URL(string: wallpaper.path) {
            return url.pathExtension.lowercased()
        }
        return (wallpaper.path as NSString).pathExtension.lowercased()
    }
    
    var body: some View {        ZStack {
            // Background
            Color.black
            
            // Media Content (Full View)
            GeometryReader { geo in
                Group {
                    let ext = fileExtension
                    
                    if ["mp4", "mov"].contains(ext) {
                        if let player = player {
                            CustomVideoPlayer(player: player, scalingOption: scalingOption)
                                .onAppear {
                                    if isVideoPlaying {
                                        player.play()
                                    }
                                }
                                .onDisappear {
                                    player.pause()
                                }
                                .onTapGesture {
                                    if isVideoPlaying {
                                        player.pause()
                                    } else {
                                        player.play()
                                    }
                                    isVideoPlaying.toggle()
                                }
                                .overlay(
                                    Group {
                                        if !isVideoPlaying {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 50))
                                                .foregroundColor(.white.opacity(0.6))
                                                .shadow(color: .black.opacity(0.5), radius: 10)
                                        }
                                    }
                                )
                        } else {
                            loadingPlaceholder
                        }
                    } else if ext == "gif" {
                        if isImageLoading {
                            loadingPlaceholder
                        } else if imageLoadFailed {
                            errorPlaceholder
                        } else if let image = loadedImage {
                            GIFAnimatingView(image: image, scalingOption: scalingOption)
                        } else {
                            loadingPlaceholder
                        }
                    } else if ["jpg", "jpeg", "png"].contains(ext) {
                        if isImageLoading {
                            loadingPlaceholder
                        } else if imageLoadFailed {
                            errorPlaceholder
                        } else if let image = loadedImage {
                            let customAspectRatio = (scalingOption == .stretch) ? (geo.size.height > 0 ? geo.size.width / geo.size.height : 1) : nil
                            let contentMode: ContentMode = (scalingOption == .fill) ? .fill : .fit
                            
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(customAspectRatio, contentMode: contentMode)
                                .clipped()
                        } else {
                            loadingPlaceholder
                        }
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            
            // Time Display Overlay
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Text(formatDate(currentTime))
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundStyle(getClockColor().opacity(0.9))
                            .padding(.bottom, -3)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text(formatTime(currentTime))
                            .font(getClockFont(size: CGFloat(clockFontSize)))
                            .foregroundStyle(getClockColor())
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 80)
                    Spacer()
                }
                Spacer()
            }
            
            // Top Left Close Button & Top Right Edit Button
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                    }
                            )
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help("Close Preview")
                    .padding(.leading, 24)
                    .padding(.top, 24)
                    
                    Spacer()
                    
                    Button(action: {
                        showEditPanel.toggle()
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                    }
                            )
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help("Customize Clock")
                    .padding(.trailing, 24)
                    .padding(.top, 24)
                    .popover(isPresented: $showEditPanel, arrowEdge: .bottom) {
                        editPanelContent
                    }
                }
                Spacer()
            }
            

            
            // Bottom Info & Controls Bar
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wallpaper.name)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 150, alignment: .leading)
                        
                        let ext = fileExtension
                        let fileType = ["mp4", "mov"].contains(ext) ? "Video" :
                                      ext == "gif" ? "GIF" :
                                      ["jpg", "jpeg", "png"].contains(ext) ? "Image" : "File"
                        let sizeString = wallpaper.fileSize > 0 ? " • \(ByteCountFormatter.string(fromByteCount: wallpaper.fileSize, countStyle: .file))" : " • Online"
                        Text("\(fileType)\(sizeString)")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Divider().frame(height: 24).background(Color.white.opacity(0.2))
                    
                    // Aspect ratio / scaling selector
                    HStack(spacing: 2) {
                        ForEach(ContentModeOption.allCases) { option in
                            ScalingTabButton(
                                title: option.rawValue,
                                isSelected: scalingOption == option,
                                namespace: tabAnimation,
                                action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        scalingOption = option
                                    }
                                }
                            )
                        }
                    }
                    .padding(2)
                    .background {
                        Capsule()
                            .fill(.black.opacity(0.2))
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
                    
                    if ["mp4", "mov"].contains(fileExtension) {
                        Divider().frame(height: 24).background(Color.white.opacity(0.2))
                        
                        Button(action: {
                            if isVideoPlaying {
                                player?.pause()
                            } else {
                                player?.play()
                            }
                            isVideoPlaying.toggle()
                        }) {
                            Image(systemName: isVideoPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 5)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !wallpaper.path.hasPrefix("http://") && !wallpaper.path.hasPrefix("https://") {
                        Divider().frame(height: 24).background(Color.white.opacity(0.2))
                        
                        Button(action: {
                            service.set_wp(wallpaper)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(NSLocalizedString("set_wallpaper", comment: "set wallpaper"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                        .buttonStyle(MaterialButtonStyle())
                    } else {
                        Divider().frame(height: 24).background(Color.white.opacity(0.2))
                        
                        if isDownloading {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                    Circle()
                                        .trim(from: 0, to: max(0.05, downloadProgress))
                                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                }
                                .frame(width: 14, height: 14)
                                
                                Text("\(Int(downloadProgress * 100))%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        } else {
                            Button(action: downloadWallpaper) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Download")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                            }
                            .buttonStyle(MaterialButtonStyle())
                        }
                    }
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
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.2), value: isVisible)
        }
        .ignoresSafeArea()
        .onAppear {
            let ext = fileExtension
            if ["mp4", "mov"].contains(ext) {
                let url: URL
                if wallpaper.path.hasPrefix("http://") || wallpaper.path.hasPrefix("https://") {
                    url = URL(string: wallpaper.path)!
                } else {
                    url = URL(fileURLWithPath: wallpaper.path)
                }
                player = AVPlayer(url: url)
                player?.volume = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    player?.play()
                }
            } else if ["jpg", "jpeg", "png", "gif"].contains(ext) {
                isImageLoading = true
                imageLoadFailed = false
                let path = wallpaper.path
                DispatchQueue.global(qos: .userInitiated).async {
                    let image: NSImage?
                    if path.hasPrefix("http://") || path.hasPrefix("https://") {
                        if let url = URL(string: path), let data = try? Data(contentsOf: url) {
                            image = NSImage(data: data)
                        } else {
                            image = nil
                        }
                    } else {
                        image = NSImage(contentsOfFile: path)
                    }
                    DispatchQueue.main.async {
                        if let image = image {
                            self.loadedImage = image
                        } else {
                            self.imageLoadFailed = true
                        }
                        self.isImageLoading = false
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isVisible = true
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            downloadTask?.cancel()
            progressObservation?.invalidate()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    private func getClockFont(size: CGFloat) -> Font {
        let weight: Font.Weight
        switch clockFontWeight {
        case "light": weight = .light
        case "regular": weight = .regular
        case "medium": weight = .medium
        case "bold": weight = .bold
        case "heavy": weight = .heavy
        default: weight = .semibold
        }
        
        let design: Font.Design
        switch clockFontDesign {
        case "monospaced": design = .monospaced
        case "serif": design = .serif
        case "default": design = .default
        default: design = .rounded
        }
        
        return .system(size: size, weight: weight, design: design)
    }
    
    private func getClockColor() -> AnyShapeStyle {
        switch clockColorType {
        case "white":
            return AnyShapeStyle(Color.white.opacity(0.95))
        case "gradient1":
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 1.0, green: 0.4, blue: 0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case "blue":
            return AnyShapeStyle(Color(red: 0.35, green: 0.78, blue: 0.98))
        case "lavender":
            return AnyShapeStyle(Color(red: 0.68, green: 0.68, blue: 0.98))
        case "pink":
            return AnyShapeStyle(Color(red: 0.98, green: 0.68, blue: 0.88))
        case "gradient2":
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.3, green: 0.9, blue: 0.7), Color(red: 0.2, green: 0.5, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case "custom":
            return AnyShapeStyle(Color(hex: clockCustomColorHex) ?? .white)
        default:
            return AnyShapeStyle(Color.white.opacity(0.95))
        }
    }
    
    struct ColorPreset {
        let type: String
        let fill: AnyShapeStyle
    }
    
    private var colorPresets: [ColorPreset] {
        [
            ColorPreset(type: "white", fill: AnyShapeStyle(Color.white)),
            ColorPreset(type: "gradient1", fill: AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 1.0, green: 0.4, blue: 0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )),
            ColorPreset(type: "blue", fill: AnyShapeStyle(Color(red: 0.35, green: 0.78, blue: 0.98))),
            ColorPreset(type: "lavender", fill: AnyShapeStyle(Color(red: 0.68, green: 0.68, blue: 0.98))),
            ColorPreset(type: "pink", fill: AnyShapeStyle(Color(red: 0.98, green: 0.68, blue: 0.88))),
            ColorPreset(type: "gradient2", fill: AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.3, green: 0.9, blue: 0.7), Color(red: 0.2, green: 0.5, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            ))
        ]
    }
    
    private func getFontForPreview(design: String) -> Font {
        let systemDesign: Font.Design
        switch design {
        case "monospaced": systemDesign = .monospaced
        case "serif": systemDesign = .serif
        case "default": systemDesign = .default
        default: systemDesign = .rounded
        }
        return .system(size: 20, weight: .bold, design: systemDesign)
    }
    
    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: clockCustomColorHex) ?? .white },
            set: { newColor in
                if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                    let r = Int(nsColor.redComponent * 255)
                    let g = Int(nsColor.greenComponent * 255)
                    let b = Int(nsColor.blueComponent * 255)
                    clockCustomColorHex = String(format: "#%02X%02X%02X", r, g, b)
                }
            }
        )
    }
    
    private var loadingPlaceholder: some View {
        ZStack {
            Color.black
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("Loading Preview...")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private var errorPlaceholder: some View {
        Color.gray.opacity(0.3)
            .overlay {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.5))
            }
    }
    
    private var editPanelContent: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Font & Color")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Font Selection Row
            HStack(spacing: 16) {
                ForEach(["rounded", "monospaced", "serif", "default"], id: \.self) { design in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            clockFontDesign = design
                        }
                    }) {
                        Text("12")
                            .font(getFontForPreview(design: design))
                            .foregroundColor(.primary)
                            .frame(width: 48, height: 48)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(clockFontDesign == design ? Color.accent.opacity(0.1) : Color.primary.opacity(0.05))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(clockFontDesign == design ? Color.accent : Color.clear, lineWidth: 2)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            // Size Slider Row
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Size")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(clockFontSize))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Slider(value: $clockFontSize, in: 48...240)
                    .tint(Color.accentColor)
            }
            .padding(.horizontal, 16)
            
            // Color Selection Row
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Custom Color Picker Circle
                        ZStack {
                            AngularGradient(
                                colors: [.red, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            )
                            .clipShape(Circle())
                            .frame(width: 32, height: 32)
                            
                            ColorPicker("", selection: customColorBinding)
                                .labelsHidden()
                                .scaleEffect(1.5)
                                .opacity(0.015)
                                .frame(width: 32, height: 32)
                                .clipped()
                        }
                        .frame(width: 32, height: 32)
                        .overlay {
                            if clockColorType == "custom" {
                                Circle()
                                    .stroke(Color.accent, lineWidth: 2)
                                    .frame(width: 38, height: 38)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                clockColorType = "custom"
                            }
                        }
                        
                        // Presets
                        ForEach(colorPresets, id: \.type) { preset in
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    clockColorType = preset.type
                                }
                            }) {
                                Circle()
                                    .fill(preset.fill)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if clockColorType == preset.type {
                                            Circle()
                                                .stroke(Color.accent, lineWidth: 2)
                                                .frame(width: 38, height: 38)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
            }
            
            // Font Weight Selection Row
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Weight")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(clockFontWeight.capitalized)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                
                HStack(spacing: 12) {
                    Text("A")
                        .font(.system(size: 14, weight: .light, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    CustomWeightSlider(weight: $clockFontWeight)
                    
                    Text("A")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 290)
        .padding(.vertical, 8)
    }

    private func downloadWallpaper() {
        guard let downloadURL = URL(string: wallpaper.path) else { return }
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let wpStorageDir = home.appendingPathComponent(".local/share/paper/wallpaper")
        
        do {
            try FileManager.default.createDirectory(at: wpStorageDir, withIntermediateDirectories: true)
            
            let fileName = "\(wallpaper.name)-\(downloadURL.lastPathComponent)"
            let destinationURL = wpStorageDir.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
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
                    return
                }
                
                guard let tempURL = tempURL else { return }
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WallpaperDownloadCompleted"),
                            object: nil
                        )
                        // Update preview wallpaper to the local path
                        let newWp = endup_wp(
                            id: wallpaper.id,
                            name: wallpaper.name,
                            path: destinationURL.path,
                            preview: wallpaper.preview,
                            createdDate: wallpaper.createdDate,
                            fileSize: wallpaper.fileSize
                        )
                        withAnimation(.easeInOut(duration: 0.3)) {
                            service.previewWallpaper = newWp
                        }
                    }
                } catch {}
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
}

extension Color {
    func toHex() -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct CustomVideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    let scalingOption: QuickPreviewOverlay.ContentModeOption
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
        switch scalingOption {
        case .fit:
            nsView.videoGravity = .resizeAspect
        case .fill:
            nsView.videoGravity = .resizeAspectFill
        case .stretch:
            nsView.videoGravity = .resize
        }
    }
}

struct GIFAnimatingView: NSViewRepresentable {
    let image: NSImage
    let scalingOption: QuickPreviewOverlay.ContentModeOption
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.animates = true
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
        
        switch scalingOption {
        case .fit:
            nsView.imageScaling = .scaleProportionallyUpOrDown
            nsView.wantsLayer = false
        case .stretch:
            nsView.imageScaling = .scaleAxesIndependently
            nsView.wantsLayer = false
        case .fill:
            nsView.imageScaling = .scaleNone
            nsView.wantsLayer = true
            nsView.layer?.contentsGravity = .resizeAspectFill
        }
    }
}

struct ScalingTabButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .black : (isHovered ? .white : .white.opacity(0.6)))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .matchedGeometryEffect(id: "activeScalingTab", in: namespace)
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

struct CustomWeightSlider: View {
    @Binding var weight: String
    let weights = ["light", "regular", "medium", "semibold", "bold", "heavy"]
    
    private var weightIndex: Double {
        Double(weights.firstIndex(of: weight) ?? 3)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let stepWidth = width / CGFloat(max(1, weights.count - 1))
            let currentX = CGFloat(weightIndex) * stepWidth
            
            ZStack(alignment: .leading) {
                // Background Track (Thin to Thick)
                TrackShape()
                    .fill(Color.primary.opacity(0.1))
                
                // Active Track
                TrackShape()
                    .fill(Color.accentColor)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle().frame(width: currentX)
                            Spacer(minLength: 0)
                        }
                    )
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .frame(width: 20, height: 20)
                    .offset(x: currentX - 10)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let dragX = max(0, min(value.location.x, width))
                                let index = Int(round(dragX / stepWidth))
                                let safeIndex = max(0, min(index, weights.count - 1))
                                if weights[safeIndex] != weight {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        weight = weights[safeIndex]
                                    }
                                }
                            }
                    )
            }
            .frame(height: 20)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: 20)
    }
}

struct TrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let minHeight: CGFloat = 2
        let maxHeight: CGFloat = 8
        
        path.move(to: CGPoint(x: 0, y: rect.midY - minHeight / 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - maxHeight / 2))
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.midY), radius: maxHeight / 2, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: rect.midY + minHeight / 2))
        path.addArc(center: CGPoint(x: 0, y: rect.midY), radius: minHeight / 2, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}