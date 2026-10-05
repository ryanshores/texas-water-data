import SwiftUI
import TexasWaterCore

struct ReservoirListView: View {
    enum SortOrder: String, CaseIterable, Identifiable {
        case name = "Name"
        case fullest = "Most full"
        case lowest = "Least full"
        case rising = "Rising fastest"
        case falling = "Falling fastest"

        var id: String { rawValue }
    }

    @EnvironmentObject private var store: ReservoirDataStore
    @State private var searchText = ""
    @State private var selectedBasin = "All basins"
    @State private var sortOrder: SortOrder = .name

    var embedded = false

    var body: some View {
        Group {
            if embedded {
                list.navigationTitle("Reservoirs")
            } else {
                NavigationStack { list.navigationTitle("Reservoirs") }
            }
        }
    }

    private var list: some View {
        List {
            if !filteredReservoirs.isEmpty {
                ReservoirMapPanel(reservoirs: filteredReservoirs)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            ForEach(filteredReservoirs) { reservoir in
                NavigationLink {
                    ReservoirDetailView(reservoir: reservoir)
                } label: {
                    ReservoirRow(reservoir: reservoir)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        store.toggleFavorite(reservoir)
                    } label: {
                        Label(
                            store.isFavorite(reservoir) ? "Unfavorite" : "Favorite",
                            systemImage: store.isFavorite(reservoir) ? "star.slash" : "star"
                        )
                    }
                    .tint(.yellow)
                }
            }
        }
        .overlay {
            if filteredReservoirs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Lake or reservoir")
        .refreshable { await store.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Basin", selection: $selectedBasin) {
                        ForEach(basins, id: \.self) { Text($0).tag($0) }
                    }
                    Divider()
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label("Filter and sort", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private var basins: [String] {
        ["All basins"] + Set(store.reservoirs.compactMap(\.basin)).sorted()
    }

    private var filteredReservoirs: [ReservoirSummary] {
        let matching = store.reservoirs.filter { reservoir in
            let matchesSearch = searchText.isEmpty
                || reservoir.shortName.localizedCaseInsensitiveContains(searchText)
                || reservoir.fullName.localizedCaseInsensitiveContains(searchText)
            let matchesBasin = selectedBasin == "All basins" || reservoir.basin == selectedBasin
            return matchesSearch && matchesBasin
        }

        return matching.sorted { left, right in
            switch sortOrder {
            case .name:
                left.shortName.localizedCaseInsensitiveCompare(right.shortName) == .orderedAscending
            case .fullest:
                (left.percentFull ?? -Double.infinity) > (right.percentFull ?? -Double.infinity)
            case .lowest:
                (left.percentFull ?? Double.infinity) < (right.percentFull ?? Double.infinity)
            case .rising:
                (left.trend.sevenDays ?? -Double.infinity) > (right.trend.sevenDays ?? -Double.infinity)
            case .falling:
                (left.trend.sevenDays ?? Double.infinity) < (right.trend.sevenDays ?? Double.infinity)
            }
        }
    }
}
