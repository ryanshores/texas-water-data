import Foundation
import SwiftUI
import TexasWaterCore

enum WaterFormatting {
    static func percent(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(1))) + "%" } ?? "Not available"
    }

    static func change(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.sign(strategy: .always()).precision(.fractionLength(1))) + " pts"
    }

    static func feet(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(2))) + " ft" } ?? "—"
    }

    static func acreFeet(_ value: Double?) -> String {
        value.map { $0.formatted(.number.notation(.compactName)) + " acre-ft" } ?? "—"
    }

    static func acres(_ value: Double?) -> String {
        value.map { $0.formatted(.number.notation(.compactName)) + " acres" } ?? "—"
    }
}

extension Color {
    static let waterBlue = Color(red: 0.03, green: 0.42, blue: 0.68)

    static func reservoirStatus(_ status: ReservoirStatus) -> Color {
        switch status {
        case .nearFull: return .blue
        case .normal: return .cyan
        case .low: return .orange
        case .critical: return .red
        case .unavailable: return .gray
        }
    }
}

extension ReservoirStatus {
    var label: String {
        switch self {
        case .nearFull: return "Near full"
        case .normal: return "Normal"
        case .low: return "Low"
        case .critical: return "Critically low"
        case .unavailable: return "Unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .nearFull: return "drop.fill"
        case .normal: return "drop.halffull"
        case .low: return "drop"
        case .critical: return "exclamationmark.triangle.fill"
        case .unavailable: return "questionmark.circle"
        }
    }
}
