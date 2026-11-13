import SwiftUI
import AVKit

struct ParkedVideoView: View {
    @StateObject private var model = VideoPlayerViewModel()
    @Environment(\.scenePhase) private var scenePhase
    let prepareForVideo: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Watch while parked", systemImage: "parkingsign.circle")
                        .font(.title2.bold())
                    Text("In a supported parked vehicle, choose the car display using AirPlay. The vehicle and system control whether video can appear on that display.")
                        .foregroundStyle(.secondary)
                    TextField("HTTPS video URL", text: $model.urlText)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("videoURL")
                    Text("Use a direct MP4 or HLS stream you have permission to watch. Website pages and subscription services may require their own player.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Load video") {
                        prepareForVideo()
                        model.load()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("loadVideo")
                    if model.isLoading { ProgressView("Loading video...") }
                    if let message = model.errorMessage {
                        Text(message).foregroundStyle(.red)
                            .accessibilityIdentifier("videoError")
                    }
                    if let player = model.player {
                        NativeVideoPlayer(player: player)
                            .frame(minHeight: 220).aspectRatio(16 / 9, contentMode: .fit)
                        HStack {
                            VideoRoutePicker().frame(width: 44, height: 44)
                                .accessibilityLabel("Choose AirPlay display")
                            Text("Choose a display").font(.subheadline)
                            Spacer()
                            Button("Close video") { model.stop() }
                        }
                        Text("Press Play in the player to start. If the vehicle stops allowing video, the system may continue audio only.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding()
            }.navigationTitle("Parked Video")
        }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.pause() }
        }
    }
}

private struct NativeVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = false
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player = nil
    }
}

private struct VideoRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        return picker
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) { }
}
