import Foundation
import ImageIO
import SwiftUI
import TexasWaterCore
import UIKit

struct DroughtHydrologyContextView: View {
    let context: DroughtHydrologyContext
    @State private var selectedLayerID: String

    init(context: DroughtHydrologyContext) {
        self.context = context
        _selectedLayerID = State(initialValue: context.soilMoisture.id)
    }

    private var layers: [DroughtRasterLayer] {
        [context.soilMoisture] + context.indices
    }

    private var selectedLayer: DroughtRasterLayer {
        layers.first(where: { $0.id == selectedLayerID }) ?? context.soilMoisture
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Drought context")
                .font(.title3.bold())

            StreamflowSummaryCard(summary: context.streamflow)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Conditions layers")
                        .font(.headline)
                    Spacer()
                    Picker("Conditions layer", selection: $selectedLayerID) {
                        ForEach(layers) { layer in
                            Text(layer.title).tag(layer.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                DroughtRasterLayerCard(layer: selectedLayer)
            }
        }
        .padding(.horizontal)
    }
}

private struct StreamflowSummaryCard: View {
    let summary: StreamflowSummary

    private var status: (title: String, color: Color) {
        guard let percentile = summary.medianPercentile else {
            return ("No current percentile", .secondary)
        }
        switch percentile {
        case ..<10: return ("Much below normal", .red)
        case ..<25: return ("Below normal", .orange)
        case ...75: return ("Within normal range", .teal)
        case ...90: return ("Above normal", .blue)
        default: return ("Much above normal", .indigo)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Streamflow", systemImage: "water.waves")
                    .font(.headline)
                Spacer()
                Text(status.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(status.color)
            }

            Text("30-day flow percentiles from \(summary.gaugeCount) representative USGS streamgages · observed \(summary.observedAt)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                streamflowMetric(
                    title: "Median",
                    value: summary.medianPercentile.map { String(format: "%.0fth", $0) } ?? "—",
                    tint: status.color
                )
                streamflowMetric(
                    title: "Below normal",
                    value: "\(summary.belowNormalGaugeCount)",
                    tint: .orange
                )
                streamflowMetric(
                    title: "Above normal",
                    value: "\(summary.aboveNormalGaugeCount)",
                    tint: .blue
                )
            }

            Text("Percentiles compare each gauge’s 30-day flow with its historical flow for this time of year.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: summary.sourceURL)!) {
                Label("View official streamflow map", systemImage: "arrow.up.right.square")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Streamflow conditions, \(status.title), median \(summary.medianPercentile.map { String(format: "%.0f", $0) } ?? "unavailable") percentile")
    }

    private func streamflowMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DroughtRasterLayerCard: View {
    let layer: DroughtRasterLayer
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(layer.title)
                        .font(.headline)
                    Text("Map date \(layer.mapDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Expand map", systemImage: "arrow.up.left.and.arrow.down.right") {
                    isExpanded = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }

            RemoteRasterImage(url: URL(string: layer.mapURL))
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("\(layer.title) map dated \(layer.mapDate)")

            Text(layer.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: layer.sourceURL)!) {
                Label("Open official map and legend", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .fullScreenCover(isPresented: $isExpanded) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        RemoteRasterImage(url: URL(string: layer.mapURL))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .accessibilityLabel("\(layer.title) map dated \(layer.mapDate)")
                        Text(layer.description)
                            .font(.body)
                            .padding(.horizontal)
                        Link(destination: URL(string: layer.sourceURL)!) {
                            Label("Open official map and legend", systemImage: "arrow.up.right.square")
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .navigationTitle(layer.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isExpanded = false }
                    }
                }
            }
        }
    }
}

private struct RemoteRasterImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if didFail {
                ContentUnavailableView("Map unavailable", systemImage: "wifi.exclamationmark")
                    .font(.caption)
            } else {
                ProgressView("Loading map…")
                    .font(.caption)
            }
        }
        .task(id: url) {
            image = nil
            didFail = false
            guard let url else {
                didFail = true
                return
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      let thumbnail = Self.thumbnail(from: data) else {
                    didFail = true
                    return
                }
                image = thumbnail
            } catch {
                didFail = true
            }
        }
    }

    private static func thumbnail(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_600,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }
}
