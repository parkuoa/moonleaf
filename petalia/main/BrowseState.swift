import SwiftUI
import Combine

class BrowseState: ObservableObject {
    static let shared = BrowseState()
    
    @Published var searchQuery = ""
    @Published var isSearchExpanded = false
    @Published var showSortDropdown = false
    @Published var showFilters = false
    
    @Published var chosen_prov: Set<WallpaperProvider> = [.wallhaven]
    @Published var chosen_categ: WHCategory = .all
    @Published var chosen_purity: Set<WHPurityStatus> = [.sfw]
    @Published var selectedResolution: ResolutionFilter = .all
    @Published var activeResolutionFilter: ResolutionFilter = .all
    @Published var selectedColor: String? = nil
    
    let resetPageAndLoadTrigger = PassthroughSubject<Void, Never>()
}

enum ResolutionFilter: String, CaseIterable {
    case hd = "HD"
    case fullHd = "Full HD"
    case wqhd = "WQHD"
    case uhd4k = "4K UHD"
    case all = "All"
    
    var displayName: String {
        switch self {
        case .hd: return "HD"
        case .fullHd: return "Full HD"
        case .wqhd: return "WQHD"
        case .uhd4k: return "4K"
        case .all: return NSLocalizedString("filter_resolution_all", comment: "All")
        }
    }
    
    func matches(width: Int, height: Int) -> Bool {
        switch self {
        case .all: return true
        case .hd:
            let totalPixels = width * height
            return totalPixels >= 800_000 && totalPixels < 1_500_000
        case .fullHd:
            let totalPixels = width * height
            return totalPixels >= 1_500_000 && totalPixels < 3_000_000
        case .wqhd:
            let totalPixels = width * height
            return totalPixels >= 3_000_000 && totalPixels < 5_000_000
        case .uhd4k:
            let totalPixels = width * height
            return totalPixels >= 5_000_000
        }
    }
}
