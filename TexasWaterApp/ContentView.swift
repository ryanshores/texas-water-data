import SwiftUI
import TexasWaterCore

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "water.waves")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                Text("Texas Water")
                    .font(.largeTitle.bold())

                Text("Reservoir monitoring groundwork is ready. The next phase builds the Today dashboard, favorites, movers, and detail charts.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Label("Phase 0 complete", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .padding(32)
            .navigationTitle("Today")
        }
    }
}

#Preview {
    ContentView()
}
