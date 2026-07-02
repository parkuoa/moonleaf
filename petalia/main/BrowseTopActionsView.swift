import SwiftUI

struct BrowseTopActionsView: View {
    @StateObject private var state = BrowseState.shared
    @AppStorage("browse_sorting") private var chosen_sorting: WHSort = .date_added
    @AppStorage("browse_order") private var chosen_order: WHOrder = .desc
    @AppStorage("pexelsAPIKey") private var pexelsAPIKeyStr: String = "" // Wait, API Key logic?

    var body: some View {
        HStack(spacing: 12) {
            // Search Button
            if state.isSearchExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    TextField(NSLocalizedString("browse_search_placeholder", comment: "Search..."), text: $state.searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .onSubmit {
                            state.resetPageAndLoadTrigger.send()
                        }
                    
                    if !state.searchQuery.isEmpty {
                        Button(action: {
                            state.searchQuery = ""
                            state.resetPageAndLoadTrigger.send()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                state.isSearchExpanded = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .frame(width: 250)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        state.isSearchExpanded = true
                    }
                }) {
                    Image(systemName: "magnifyingglass")
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
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            }
            
            // Sort Button
            Button(action: { state.showSortDropdown.toggle() }) {
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
            .popover(isPresented: $state.showSortDropdown, arrowEdge: .bottom) {
                sortDropdownView
            }
            
            // Filters Button
            Button(action: { state.showFilters.toggle() }) {
                Image(systemName: "slider.horizontal.3")
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
            .popover(isPresented: $state.showFilters) {
                filtersView
                    .frame(width: 300)
                    .padding()
            }
        }
    }
    
    private var sortDropdownView: some View {
        VStack(spacing: 4) {
            ForEach(WHSort.allCases, id: \.self) { sorting in
                Button(action: {
                    chosen_sorting = sorting
                    state.showSortDropdown = false
                    state.resetPageAndLoadTrigger.send()
                }) {
                    HStack {
                        Text(sorting.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(chosen_sorting == sorting ? .primary : .secondary)
                        Spacer()
                        if chosen_sorting == sorting {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(chosen_sorting == sorting ? 0.08 : 0.001)))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            ForEach([WHOrder.desc, WHOrder.asc], id: \.self) { order in
                Button(action: {
                    chosen_order = order
                    state.showSortDropdown = false
                    state.resetPageAndLoadTrigger.send()
                }) {
                    HStack {
                        Text(order == .desc ? NSLocalizedString("browse_desc", comment: "") : NSLocalizedString("browse_asc", comment: ""))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(chosen_order == order ? .primary : .secondary)
                        Spacer()
                        if chosen_order == order {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(chosen_order == order ? 0.08 : 0.001)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 160)
    }
    
    private var filtersView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("browse_filters", comment: "Filters"))
                .font(Font(font_loader.bold(size: 16)))
            
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("browse_provider", comment: "Source"))
                    .font(Font(font_loader.regular(size: 12)))
                    .foregroundColor(.secondary)
                
                MultiSegmentSelector(
                    options: WallpaperProvider.allCases,
                    selection: $state.chosen_prov,
                    displayName: { $0.displayName },
                    icon: { $0.icon }
                )
            }
            
            if state.chosen_prov.contains(.wallhaven) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("browse_purity", comment: "Purity"))
                        .font(Font(font_loader.regular(size: 12)))
                        .foregroundColor(.secondary)
                    
                    MultiSegmentSelector(
                        options: WHPurityStatus.allCases,
                        selection: $state.chosen_purity,
                        displayName: { $0.displayName },
                        icon: nil
                    )
                }
            }
            
            Button(action: {
                state.showFilters = false
                state.resetPageAndLoadTrigger.send()
            }) {
                Text(NSLocalizedString("browse_apply", comment: "Apply Filters"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle())
        }
    }
}
