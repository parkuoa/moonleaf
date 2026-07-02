//
//  BrowseView.swift
//  petalia
//
//  Copyright © 2026 naomisphere. All rights reserved.
//

import SwiftUI
import Combine

struct BrowseView: View {
    @StateObject private var WHServ = WHService()
    @StateObject private var pexelsServ = PexelsService()
    @StateObject private var state = BrowseState.shared
    @AppStorage("browse_sorting") private var chosen_sorting: WHSort = .date_added
    @AppStorage("browse_order") private var chosen_order: WHOrder = .desc
    
    private var cachedWallpapers: [AnyWallpaper] {
        var items: [AnyWallpaper] = []
        if state.chosen_prov.contains(.wallhaven) {
            items.append(contentsOf: WHServ.wallpapers)
        }
        if state.chosen_prov.contains(.pexels) {
            items.append(contentsOf: pexelsServ.videos)
        }
        return items.filter { item in
            state.activeResolutionFilter.matches(width: item.width, height: item.height)
        }
    }
    
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var isPaginationLoading = false
    @State private var showAPIKeyAlert = false
    @State private var apiKey = ""
    @State private var pexelsAPIKey: String = ""
    @State private var showPexelsKeyAlert = false
    @State private var pexelsKeyError = false
    @State private var showColorPopover = false
    

    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let spacing: CGFloat = 20
            let columnCount = max(2, Int((width - 48) / (260 + spacing)))
            let colWidth = (width - 48 - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 48)
                    
                    toolbarView
                    
                    ZStack {
                        if isLoading {
                            loadingView
                                .frame(minHeight: max(200, geo.size.height - 180))
                        } else if cachedWallpapers.isEmpty {
                            emptyStateView
                                .frame(minHeight: max(200, geo.size.height - 180))
                        } else {
                            LazyMasonryContent(
                                wallpapers: cachedWallpapers,
                                columnCount: columnCount,
                                spacing: spacing,
                                colWidth: colWidth,
                                lastItemID: cachedWallpapers.last?.id,
                                onLastAppeared: loadNextPage
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            .padding(.top, 8)
                        }
                    }
                    
                    if state.chosen_prov.contains(.pexels) {
                        Button(action: {
                            if let url = URL(string: "https://www.pexels.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Photos provided by Pexels")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onReceive(state.resetPageAndLoadTrigger) { _ in
            currentPage = 1
            loadWallpapers()
        }
        .onChange(of: state.chosen_categ) { _ in
            currentPage = 1
            loadWallpapers()
        }
        .onChange(of: state.selectedResolution) { newValue in
            state.activeResolutionFilter = newValue
            currentPage = 1
            loadWallpapers()
        }
        .onChange(of: state.selectedColor) { _ in
            currentPage = 1
            loadWallpapers()
        }
        .onChange(of: state.chosen_prov) { newValue in
            if newValue.contains(.pexels) && pexelsAPIKey.isEmpty {
                DispatchQueue.main.async {
                    state.chosen_prov.remove(.pexels)
                    showPexelsKeyAlert = true
                }
            } else {
                currentPage = 1
                loadWallpapers()
            }
        }
        .onAppear {
            loadPexelsAPIKey()
            if WHServ.wallpapers.isEmpty && pexelsServ.videos.isEmpty {
                loadWallpapers()
            }
        }
        .alert("Pexels API Key", isPresented: $showPexelsKeyAlert) {
            TextField("Enter API Key", text: $apiKey)
            Button("Save") {
                let keyToTry = apiKey
                pexelsServ.validateAPIKey(keyToTry) { isValid in
                    DispatchQueue.main.async {
                        if isValid {
                            pexelsAPIKey = keyToTry
                            savePexelsAPIKey(keyToTry)
                            pexelsServ.setAPIKey(keyToTry)
                            state.chosen_prov.insert(.pexels)
                            apiKey = ""
                            loadWallpapers()
                        } else {
                            pexelsKeyError = true
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                apiKey = ""
            }
        } message: {
            Text("Get a free API key from pexels.com")
        }
        .alert("Invalid API Key", isPresented: $pexelsKeyError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The API key you entered appeared to be invalid. Please check and try again.")
        }
    }
    
    private var toolbarView: some View {
        HStack(alignment: .bottom) {
            Text("Browse")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                SegmentSelector(
                    options: WHCategory.allCases,
                    selection: $state.chosen_categ,
                    displayName: { $0.displayName }
                )
                
                SegmentSelector(
                    options: ResolutionFilter.allCases,
                    selection: $state.selectedResolution,
                    displayName: { $0.displayName }
                )
                
                HStack(spacing: 0) {
                    Button(action: { showColorPopover.toggle() }) {
                        HStack(spacing: 6) {
                            if let colorHex = state.selectedColor {
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 12, height: 12)
                                    .overlay {
                                        Circle().stroke(.primary.opacity(0.15), lineWidth: 0.5)
                                    }
                            } else {
                                Circle()
                                    .fill(LinearGradient(colors: [.red, .green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 12, height: 12)
                            }
                            
                            Text("Color")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(state.selectedColor != nil ? Color.primary : Color.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            if state.selectedColor != nil {
                                Capsule()
                                    .fill(Color.mainSurface)
                                    .overlay {
                                        Capsule()
                                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                    }
                                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .popover(isPresented: $showColorPopover, arrowEdge: .bottom) {
                    colorPopoverView
                }
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }
    
    private func loadPexelsAPIKey() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/petalia")
        let keyFile = configDir.appendingPathComponent("pexels_api_key.txt")
        
        do {
            pexelsAPIKey = try String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            pexelsServ.setAPIKey(pexelsAPIKey)
        } catch {
            pexelsAPIKey = ""
        }
    }
    
    private func savePexelsAPIKey(_ key: String) {
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/petalia")
        let keyFile = configDir.appendingPathComponent("pexels_api_key.txt")
        
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            try key.write(to: keyFile, atomically: true, encoding: .utf8)
        } catch {
        }
    }
    
    

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text(NSLocalizedString("browse_loading", comment: "Loading wallpapers..."))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(Font(font_loader.regular(size: 48)))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("browse_no_results", comment: "No wallpapers found"))
                .font(Font(font_loader.regular(size: 16)))
            Text(NSLocalizedString("browse_try_search", comment: "Try adjusting your search or filters"))
                .font(Font(font_loader.regular(size: 14)))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadWallpapers() {
        isLoading = true
        isPaginationLoading = false
        let group = DispatchGroup()
        
        if state.chosen_prov.contains(.wallhaven) {
            group.enter()
            WHServ.searchWallpapers(
                query: state.searchQuery.isEmpty ? nil : state.searchQuery,
                sorting: chosen_sorting,
                order: chosen_order,
                purity: state.chosen_purity,
                category: state.chosen_categ,
                color: state.selectedColor,
                page: currentPage
            ) {
                group.leave()
            }
        } else {
            WHServ.wallpapers = []
        }
        
        if state.chosen_prov.contains(.pexels) {
            if !pexelsAPIKey.isEmpty {
                group.enter()
                pexelsServ.searchVideos(
                    query: state.searchQuery.isEmpty ? "nature" : state.searchQuery,
                    page: currentPage,
                    perPage: 24
                ) {
                    group.leave()
                }
            } else {
                pexelsServ.videos = []
            }
        } else {
            pexelsServ.videos = []
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
    
    private func loadNextPage() {
        guard !isPaginationLoading else { return }
        isPaginationLoading = true
        
        currentPage += 1
        let group = DispatchGroup()
        
        if state.chosen_prov.contains(.wallhaven) {
            group.enter()
            WHServ.loadMoreWallpapers(
                query: state.searchQuery.isEmpty ? nil : state.searchQuery,
                sorting: chosen_sorting,
                order: chosen_order,
                purity: state.chosen_purity,
                category: state.chosen_categ,
                color: state.selectedColor,
                page: currentPage
            ) {
                group.leave()
            }
        }
        if state.chosen_prov.contains(.pexels) && !pexelsAPIKey.isEmpty {
            group.enter()
            pexelsServ.loadMoreVideos(
                query: state.searchQuery.isEmpty ? "nature" : state.searchQuery,
                page: currentPage,
                perPage: 24
            ) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isPaginationLoading = false
        }
    }
    
    private let wallhavenColors = [
        "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399",
        "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900",
        "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300",
        "000000", "999999", "cccccc", "ffffff", "424153"
    ]
    
    private var colorPopoverView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Color")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                if state.selectedColor != nil {
                    Button(action: {
                        state.selectedColor = nil
                        showColorPopover = false
                    }) {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            
            let columns = Array(repeating: GridItem(.fixed(20), spacing: 6), count: 6)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(wallhavenColors, id: \.self) { colorHex in
                    Button(action: {
                        state.selectedColor = colorHex
                        showColorPopover = false
                    }) {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 20, height: 20)
                            .overlay {
                                Circle()
                                    .stroke(state.selectedColor == colorHex ? Color.primary : Color.primary.opacity(0.15), lineWidth: state.selectedColor == colorHex ? 2.0 : 0.5)
                            }
                            .shadow(color: .black.opacity(0.05), radius: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(width: 170)
    }
}

private struct LazyMasonryContent: View {
    let wallpapers: [AnyWallpaper]
    let columnCount: Int
    let spacing: CGFloat
    let colWidth: CGFloat
    let lastItemID: String?
    let onLastAppeared: () -> Void

    private var columns: [[AnyWallpaper]] {
        guard columnCount > 0 else { return [] }
        var cols = Array(repeating: [AnyWallpaper](), count: columnCount)
        var heights = Array(repeating: CGFloat(0), count: columnCount)

        for item in wallpapers {
            let shortest = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            cols[shortest].append(item)
            let ratio = CGFloat(item.width) / CGFloat(max(1, item.height))
            let clamped = min(max(ratio, 0.65), 2.4)
            heights[shortest] += 1.0 / clamped
        }

        return cols
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columnCount, id: \.self) { colIndex in
                LazyVStack(spacing: spacing) {
                    if colIndex < columns.count {
                        ForEach(columns[colIndex]) { wallpaper in
                            BrowseWallpaperCard(item: wallpaper)
                                .onAppear {
                                    if wallpaper.id == lastItemID {
                                        onLastAppeared()
                                    }
                                }
                        }
                    }
                }
                .frame(width: colWidth)
            }
        }
    }
}

struct CBToggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .blue : .secondary)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

protocol WallpaperItem: Identifiable {
    var id: String { get }
    var width: Int { get }
    var height: Int { get }
    var previewURL: URL? { get }
    var downloadURL: URL? { get }
    var isVideo: Bool { get }
    var authorName: String? { get }
    var authorURL: URL? { get }
    var itemURL: URL? { get }
}

struct AnyWallpaper: Identifiable, Equatable {
    let id: String
    let width: Int
    let height: Int
    let previewURL: URL?
    let downloadURL: URL?
    let isVideo: Bool
    let authorName: String?
    let authorURL: URL?
    let itemURL: URL?
    let provider: WallpaperProvider
    private let original: any WallpaperItem
    
    init<T: WallpaperItem>(_ item: T, provider: WallpaperProvider) {
        self.id = item.id
        self.width = item.width
        self.height = item.height
        self.previewURL = item.previewURL
        self.downloadURL = item.downloadURL
        self.isVideo = item.isVideo
        self.authorName = item.authorName
        self.authorURL = item.authorURL
        self.itemURL = item.itemURL
        self.provider = provider
        self.original = item
    }
    
    static func == (lhs: AnyWallpaper, rhs: AnyWallpaper) -> Bool {
        lhs.id == rhs.id
    }
}

extension WHWallpaper: WallpaperItem {
    var width: Int { dimension_x }
    var height: Int { dimension_y }
    var previewURL: URL? { URL(string: thumbs.large) }
    var downloadURL: URL? { URL(string: path) }
    var isVideo: Bool { false }
    var authorName: String? { nil }
    var authorURL: URL? { nil }
    var itemURL: URL? { URL(string: url) }
}

enum WallpaperProvider: String, CaseIterable {
    case wallhaven = "wallhaven"
    case pexels = "pexels"
    
    var displayName: String {
        switch self {
        case .wallhaven: return "Wallhaven"
        case .pexels: return "Pexels"
        }
    }
    
    var icon: String {
        switch self {
        case .wallhaven: return "globe"
        case .pexels: return "video"
        }
    }
}

class WHService: ObservableObject {
    @Published var wallpapers: [AnyWallpaper] = []
    private let baseURL = "https://wallhaven.cc/api/v1/search"
    private var currentSeed: String?
    private var apiKey: String = ""
    
    func loadAPIKey() {
        let keyFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/macpaper/WH_API_KEY")
        if FileManager.default.fileExists(atPath: keyFile.path),
           let key = try? String(contentsOf: keyFile) {
            apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    
    func searchWallpapers(
        query: String? = nil,
        sorting: WHSort = .date_added,
        order: WHOrder = .desc,
        purity: Set<WHPurityStatus> = [.sfw],
        category: WHCategory = .all,
        color: String? = nil,
        page: Int = 1,
        completion: (() -> Void)? = nil
    ) {
        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        queryItems.append(URLQueryItem(name: "sorting", value: sorting.rawValue))
        queryItems.append(URLQueryItem(name: "order", value: order.rawValue))
        
        var purityStr = ""
        purityStr += purity.contains(.sfw) ? "1" : "0"
        purityStr += purity.contains(.sketchy) ? "1" : "0"
        purityStr += purity.contains(.nsfw) ? "1" : "0"
        if purityStr == "000" { purityStr = "100" }
        queryItems.append(URLQueryItem(name: "purity", value: purityStr))
        
        queryItems.append(URLQueryItem(name: "categories", value: category.rawValue))
        if let color = color, !color.isEmpty {
            queryItems.append(URLQueryItem(name: "colors", value: color))
        }
        
        queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
        if sorting == .random {
            if page == 1 {
                currentSeed = nil
            } else if let seed = currentSeed {
                queryItems.append(URLQueryItem(name: "seed", value: seed))
            }
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        if !apiKey.isEmpty {
            request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { completion?() }
            
            if let _ = error {
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(WHResponse.self, from: data)
                DispatchQueue.main.async {
                    self.wallpapers = response.data.map { AnyWallpaper($0, provider: .wallhaven) }
                    if let seed = response.meta.seed {
                        self.currentSeed = seed
                    }
                }
            } catch {
                print("while decoding response: \(error)")
            }
        }.resume()
    }
    
    func loadMoreWallpapers(
        query: String? = nil,
        sorting: WHSort = .date_added,
        order: WHOrder = .desc,
        purity: Set<WHPurityStatus> = [.sfw],
        category: WHCategory = .all,
        color: String? = nil,
        page: Int,
        completion: (() -> Void)? = nil
    ) {
        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        queryItems.append(URLQueryItem(name: "sorting", value: sorting.rawValue))
        queryItems.append(URLQueryItem(name: "order", value: order.rawValue))
        
        var purityStr = ""
        purityStr += purity.contains(.sfw) ? "1" : "0"
        purityStr += purity.contains(.sketchy) ? "1" : "0"
        purityStr += purity.contains(.nsfw) ? "1" : "0"
        if purityStr == "000" { purityStr = "100" }
        queryItems.append(URLQueryItem(name: "purity", value: purityStr))
        
        queryItems.append(URLQueryItem(name: "categories", value: category.rawValue))
        if let color = color, !color.isEmpty {
            queryItems.append(URLQueryItem(name: "colors", value: color))
        }
        
        queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
        if sorting == .random, let seed = currentSeed {
            queryItems.append(URLQueryItem(name: "seed", value: seed))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        if !apiKey.isEmpty {
            request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { completion?() }
            if let _ = error {
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(WHResponse.self, from: data)
                DispatchQueue.main.async {
                    self.wallpapers.append(contentsOf: response.data.map { AnyWallpaper($0, provider: .wallhaven) })
                    if let seed = response.meta.seed {
                        self.currentSeed = seed
                    }
                }
            } catch {
                print("while decoding response: \(error)")
            }
        }.resume()
    }
}

class PexelsService: ObservableObject {
    @Published var videos: [AnyWallpaper] = []
    private let baseURL = "https://api.pexels.com/v1/videos"
    private var apiKey: String = ""
    private var nextPageURL: String?
    
    func setAPIKey(_ key: String) {
        apiKey = key
    }

    func validateAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: "test"),
            URLQueryItem(name: "per_page", value: "1")
        ]
        guard let url = components.url else { completion(false); return }
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                do {
                    _ = try JSONDecoder().decode(PexelsSearchResponse.self, from: data)
                    completion(true)
                } catch {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }.resume()
    }
    
    func searchVideos(query: String, page: Int = 1, perPage: Int = 15, completion: (() -> Void)? = nil) {
        guard !apiKey.isEmpty else {
            completion?()
            return
        }
        
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        
        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { completion?() }
            if let _ = error { return }
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(PexelsSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self.videos = response.videos.map { AnyWallpaper(PexelsVideoWrapper(video: $0), provider: .pexels) }
                    self.nextPageURL = response.next_page
                }
            } catch {
            }
        }.resume()
    }
    
    func loadMoreVideos(query: String, page: Int, perPage: Int = 15, completion: (() -> Void)? = nil) {
        guard !apiKey.isEmpty else {
            completion?()
            return
        }
        
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        
        guard let url = components.url else {
            completion?()
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { completion?() }
            if let _ = error { return }
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(PexelsSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self.videos.append(contentsOf: response.videos.map { AnyWallpaper(PexelsVideoWrapper(video: $0), provider: .pexels) })
                    self.nextPageURL = response.next_page
                }
            } catch {
            }
        }.resume()
    }
}

struct PexelsVideoWrapper: WallpaperItem {
    let video: PexelsVideo
    
    var id: String { String(video.id) }
    var width: Int { video.width }
    var height: Int { video.height }
    var previewURL: URL? { URL(string: video.image) }
    var downloadURL: URL? {
        let sorted = video.video_files.sorted { 
            ($0.width ?? 0) * ($0.height ?? 0) > ($1.width ?? 0) * ($1.height ?? 0) 
        }
        if let best = sorted.first, let url = URL(string: best.link) {
            return url
        }
        return nil
    }
    var isVideo: Bool { true }
    var authorName: String? { video.user?.name }
    var authorURL: URL? { video.user?.url != nil ? URL(string: video.user!.url!) : nil }
    var itemURL: URL? { video.url != nil ? URL(string: video.url!) : nil }
}

struct PexelsSearchResponse: Codable {
    let page: Int
    let per_page: Int
    let total_results: Int
    let next_page: String?
    let videos: [PexelsVideo]
}

struct PexelsVideo: Codable {
    let id: Int
    let width: Int
    let height: Int
    let url: String?
    let image: String
    let duration: Int?
    let user: PexelsUser?
    let video_files: [PexelsVideoFile]
    let video_pictures: [PexelsVideoPicture]?
}

struct PexelsUser: Codable {
    let id: Int?
    let name: String?
    let url: String?
}

struct PexelsVideoFile: Codable {
    let id: Int
    let quality: String?
    let file_type: String?
    let width: Int?
    let height: Int?
    let link: String
}

struct PexelsVideoPicture: Codable {
    let id: Int?
    let picture: String?
    let nr: Int?
}

struct WHResponse: Codable {
    let data: [WHWallpaper]
    let meta: WHMeta
}

struct WHWallpaper: Codable {
    let id: String
    let url: String
    let short_url: String
    let views: Int
    let favorites: Int
    let source: String
    let purity: String
    let category: String
    let dimension_x: Int
    let dimension_y: Int
    let resolution: String
    let ratio: String
    let file_size: Int
    let file_type: String
    let created_at: String
    let colors: [String]
    let path: String
    let thumbs: WHThumbs
}

struct WHThumbs: Codable {
    let large: String
    let original: String
    let small: String
}

struct WHMeta: Codable {
    let current_page: Int
    let last_page: Int
    let per_page: Int
    let total: Int
    let query: String?
    let seed: String?
}

enum WHSort: String, CaseIterable {
    case date_added = "date_added"
    case relevance = "relevance"
    case random = "random"
    case views = "views"
    case favorites = "favorites"
    case toplist = "toplist"
    
    var displayName: String {
        switch self {
        case .date_added: return NSLocalizedString("sort_date", comment: "Date Added")
        case .relevance: return NSLocalizedString("sort_relevance", comment: "Relevance")
        case .random: return NSLocalizedString("sort_random", comment: "Random")
        case .views: return NSLocalizedString("sort_views", comment: "Views")
        case .favorites: return NSLocalizedString("sort_favorites", comment: "Favorites")
        case .toplist: return NSLocalizedString("sort_top", comment: "Toplist")
        }
    }
}

enum WHOrder: String {
    case desc = "desc"
    case asc = "asc"
}

enum WHPurityStatus: String, CaseIterable {
    case sfw = "sfw"
    case sketchy = "sketchy"
    case nsfw = "nsfw"
    
    var displayName: String {
        switch self {
        case .sfw: return "SFW"
        case .sketchy: return "Sketchy"
        case .nsfw: return "NSFW"
        }
    }
}

enum WHCategory: String, CaseIterable {
    case general = "100"
    case anime = "010"
    case people = "001"
    case all = "111"
    
    var displayName: String {
        switch self {
        case .general: return NSLocalizedString("category_general", comment: "General")
        case .anime: return NSLocalizedString("category_anime", comment: "Anime")
        case .people: return NSLocalizedString("category_people", comment: "People")
        case .all: return NSLocalizedString("category_all", comment: "All")
        }
    }
}

class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    func getImage(forKey key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: NSImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

struct SegmentSelector<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let displayName: (T) -> String
    
    @Namespace private var ns
    @State private var hoveredItem: T? = nil
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = option
                    }
                }) {
                    Text(displayName(option))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selection == option ? Color.primary : (hoveredItem == option ? Color.primary.opacity(0.7) : Color.secondary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(Color.mainSurface)
                                    .overlay {
                                        Capsule()
                                            .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                    }
                                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "activeSegment", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        hoveredItem = hovering ? option : nil
                    }
                }
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct MultiSegmentSelector<T: Hashable>: View {
    let options: [T]
    @Binding var selection: Set<T>
    let displayName: (T) -> String
    let icon: ((T) -> String)?
    
    @State private var hoveredItem: T? = nil
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        var newSelection = selection
                        if newSelection.contains(option) {
                            if newSelection.count > 1 {
                                newSelection.remove(option)
                            }
                        } else {
                            newSelection.insert(option)
                        }
                        selection = newSelection
                    }
                }) {
                    HStack(spacing: 6) {
                        if let icon = icon {
                            Image(systemName: icon(option))
                                .font(.system(size: 11, weight: .medium))
                        }
                        Text(displayName(option))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selection.contains(option) ? Color.primary : (hoveredItem == option ? Color.primary.opacity(0.7) : Color.secondary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if selection.contains(option) {
                            Capsule()
                                .fill(Color.mainSurface)
                                .overlay {
                                    Capsule()
                                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                                }
                                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        hoveredItem = hovering ? option : nil
                    }
                }
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}