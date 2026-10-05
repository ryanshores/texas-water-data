import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: ReservoirDataStore
    @EnvironmentObject private var droughtStore: DroughtDataStore
    private let onOpenDrought: () -> Void
    @State private var majorOnly = false

    init(onOpenDrought: @escaping () -> Void = {}) {
        self.onOpenDrought = onOpenDrought
    }

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

                            droughtSummary

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
                                subtitle: "At least 85% of conservation capacity",
                                reservoirs: store.majorOnly(store.nearFull, enabled: majorOnly),
                                capacityContext: store.capacityContext,
                                emptyMessage: "No reservoirs are near full"
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await store.refresh()
                        await droughtStore.refresh()
                    }
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
                    Button { Task { await store.refresh(); await droughtStore.refresh() } } label: {
                        if store.isRefreshing || droughtStore.isLoading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(store.isRefreshing || droughtStore.isLoading)
                    .accessibilityLabel("Refresh water and drought data")
                }
            }
        }
    }

    @ViewBuilder
    private var droughtSummary: some View {
        if let summary = droughtStore.summary {
            DroughtTodayCard(summary: summary, source: droughtStore.summarySource, onOpenDetails: onOpenDrought)
            if let errorMessage = droughtStore.errorMessage {
                Label("Showing the last available drought update. \(errorMessage)", systemImage: "clock.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        } else if droughtStore.isLoading {
            HStack {
                ProgressView()
                Text("Loading drought conditions…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
        } else {
            Label(droughtStore.errorMessage ?? "Drought data is unavailable right now.", systemImage: "sun.max.trianglebadge.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
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
