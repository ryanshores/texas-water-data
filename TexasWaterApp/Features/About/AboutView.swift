import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Texas Water", systemImage: "water.waves")
                            .font(.title2.bold())
                            .foregroundStyle(Color.waterBlue)
                        Text("A quick, accessible view of reservoir conditions across Texas.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("How to read the app") {
                    Label("Near full: 95% or more", systemImage: "drop.fill")
                    Label("Low: below 25%", systemImage: "drop")
                    Label("Critically low: below 10%", systemImage: "exclamationmark.triangle.fill")
                    Text("Movement is measured in percentage points so reservoirs of different sizes can be compared fairly.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Text("Reservoir data is provided by the Texas Water Development Board. Values are best estimates, can be revised, and should not be used as the sole basis for safety or operational decisions.")
                        .font(.footnote)
                    Link("Water Data for Texas", destination: URL(string: "https://waterdatafortexas.org/reservoirs/statewide")!)
                    Link("Methodology", destination: URL(string: "https://waterdatafortexas.org/reservoirs/methodology")!)
                }

                Section("Data delivery") {
                    Text("The app normally reads the Texas Water API, which keeps a compact copy of the official data and historical observations. If the service is unavailable, it falls back to the official Water Data for Texas feeds or saved data on this device.")
                        .font(.footnote)
                    Link("Check API status", destination: URL(string: "https://texas-water-api.ryan-shores.workers.dev/health")!)
                }

                Section("Privacy") {
                    Text("Favorites and cached readings remain on this device. This version does not require an account or collect precise location.")
                        .font(.footnote)
                }

                Section("Preferences") {
                    NavigationLink("Notifications") {
                        NotificationSettingsView()
                    }
                }
            }
            .navigationTitle("About")
        }
    }
}
