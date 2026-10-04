import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: ReservoirDataStore
    @State private var majorOnly = false

    var body: some View {
        NavigationStack {
            Group {
                if let dashboard = store.dashboard {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if let error = store.errorMessage {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }

                            SummaryHeroCard(dashboard: dashboard, source: store.source)

                            Picker("Ranking scope", selection: $majorOnly) {
                                Text("All reservoirs").tag(false)
                                Text("Major capacity").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityHint("Major capacity means the largest quarter of reservoirs by conservation capacity.")

                            if store.favorites.isEmpty {
                                favoritePrompt
                            } else {
                                DashboardSection(
                                    title: "My reservoirs",
                                    subtitle: "The lakes you follow",
                                    reservoirs: store.favorites,
                                    capacityContext: store.capacityContext
                                )
                            }

                            if !store.favorites.isEmpty {
                                DashboardSection(
                                    title: "Favorite weekly summary",
                                    subtitle: "Largest seven-day movement",
                                    reservoirs: store.favorites.sorted {
                                        abs($0.trend.sevenDays ?? 0) > abs($1.trend.sevenDays ?? 0)
                                    },
                                    capacityContext: store.capacityContext,
                                    emptyMessage: "Seven-day history is still building"
                                )
                            }

                            if store.hasTrendData {
                                DashboardSection(
                                    title: "Rising fastest",
                                    subtitle: "Largest seven-day gains",
                                    reservoirs: store.majorOnly(store.rising, enabled: majorOnly),
                                    capacityContext: store.capacityContext
                                )
                                DashboardSection(
                                    title: "Falling fastest",
                                    subtitle: "Largest seven-day declines",
                                    reservoirs: store.majorOnly(store.falling, enabled: majorOnly),
                                    capacityContext: store.capacityContext
                                )
                            } else {
                                DashboardSection(
                                    title: "What’s changing",
                                    subtitle: "Seven-day movement",
                                    reservoirs: [],
                                    emptyMessage: "Trend history is still building"
                                )
                            }

                            DashboardSection(
                                title: "Lowest reservoirs",
                                subtitle: "Below 25% of conservation capacity",
                                reservoirs: store.majorOnly(store.low, enabled: majorOnly),
                                capacityContext: store.capacityContext,
                                emptyMessage: "No low reservoirs"
                            )

                            DashboardSection(
                                title: "Near full",
                                subtitle: "At least 95% of conservation capacity",
                                reservoirs: store.majorOnly(store.nearFull, enabled: majorOnly),
                                capacityContext: store.capacityContext,
                                emptyMessage: "No reservoirs are near full"
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .refreshable { await store.refresh() }
                } else if store.isLoading || store.isRefreshing {
                    ProgressView("Loading Texas water data…")
                } else {
                    ContentUnavailableView(
                        "Water data unavailable",
                        systemImage: "wifi.exclamationmark",
                        description: Text(store.errorMessage ?? "Pull to try again.")
                    )
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await store.refresh() } } label: {
                        if store.isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(store.isRefreshing)
                    .accessibilityLabel("Refresh water data")
                }
            }
        }
    }

    private var favoritePrompt: some View {
        NavigationLink {
            ReservoirListView(embedded: true)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "star")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose your reservoirs").font(.headline)
                    Text("Favorites stay at the top of Today.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
