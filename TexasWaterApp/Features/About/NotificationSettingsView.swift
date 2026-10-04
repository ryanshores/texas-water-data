import SwiftUI
import UIKit
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var alerts: LocalAlertManager

    var body: some View {
        List {
            Section {
                Text("Notifications are evaluated when Texas Water refreshes on this device. They do not require an account or send device information to the service during local development.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Favorite reservoir alerts") {
                Toggle("Low, critically low, or near full", isOn: $alerts.thresholdAlerts)
                Toggle("Rapid seven-day change", isOn: $alerts.rapidChangeAlerts)
                Toggle("Weekly favorite summary", isOn: $alerts.weeklySummary)
            }

            Section("Permission") {
                LabeledContent("System status", value: statusLabel)
                if alerts.authorizationStatus == .denied {
                    Link("Open Notification Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                } else if alerts.authorizationStatus != .authorized && alerts.authorizationStatus != .provisional {
                    Button("Allow notifications") {
                        Task { await alerts.requestAuthorization() }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: alerts.isEnabled) { _, enabled in
            if enabled, alerts.authorizationStatus == .notDetermined {
                Task { await alerts.requestAuthorization() }
            }
        }
    }

    private var statusLabel: String {
        switch alerts.authorizationStatus {
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .denied: "Not allowed"
        case .ephemeral: "Temporary"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }
}
