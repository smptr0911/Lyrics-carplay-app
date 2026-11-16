import SwiftUI

struct AirPlayGuideView: View {
    @StateObject private var model = AirPlayHelpViewModel()

    var body: some View {
        List {
            Section("Video while parked") {
                Text("Some vehicles support AirPlay video on their CarPlay display when stationary. This does not work in every CarPlay vehicle or with every YouTube video.")
                Text("Only the vehicle and iOS decide whether video is available. This app does not detect whether you are parked.")
                    .foregroundStyle(.secondary)
            }
            Section(model.compatibility.title) {
                Text(model.compatibility.explanation)
                Text("Use an iPhone and software supported by your vehicle manufacturer. An iOS update alone does not establish vehicle video support.")
            }
            Section("Set up in YouTube") {
                ForEach(Array(AirPlayCompatibilityInfo.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top) {
                        Text("\(index + 1).").monospacedDigit()
                        Text(step)
                    }
                }
                Button("Open YouTube") { Task { await model.openYouTube() } }
                    .disabled(model.isOpening)
                    .accessibilityIdentifier("openYouTube")
                Text("Opens YouTube or its website. Choose and play a video there; this button does not start AirPlay.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("youtubeLaunchError")
                }
            }
            Section("Troubleshooting") {
                ForEach([AirPlayCompatibilityInfo.unsupportedVehicle, .airPlayUnavailable]) { info in
                    DisclosureGroup(info.title) { Text(info.explanation) }
                }
                Text("If video becomes unavailable, respect the vehicle's restriction. There is no override in this app. To disconnect, use AirPlay controls in YouTube and deselect the vehicle display.")
            }
            Section("Learn more") {
                Link("Apple: Play videos with CarPlay", destination: URL(string: "https://support.apple.com/guide/iphone/play-videos-with-carplay-xykemxkw6he5/ios")!)
            }
        }
        .navigationTitle("AirPlay Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AirPlayGuideView() }
}
