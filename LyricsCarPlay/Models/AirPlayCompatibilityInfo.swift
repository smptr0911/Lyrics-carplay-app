import Foundation

/// Informational troubleshooting scenarios, never a detected vehicle eligibility result.
enum AirPlayCompatibilityInfo: String, CaseIterable, Identifiable, Sendable {
    case unknown, unsupportedVehicle, airPlayUnavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown: return "Compatibility is unknown"
        case .unsupportedVehicle: return "Vehicle does not support video"
        case .airPlayUnavailable: return "AirPlay output is missing"
        }
    }

    var explanation: String {
        switch self {
        case .unknown:
            return "This app cannot check your vehicle's video eligibility. Ask the manufacturer whether your model and infotainment software support AirPlay video in CarPlay. CarPlay audio support alone is insufficient."
        case .unsupportedVehicle:
            return "If the manufacturer says video is unsupported, these steps cannot enable it. Continue using lyrics and audio, or watch on your iPhone when safe."
        case .airPlayUnavailable:
            return "Check the vehicle's connection instructions and software requirements. YouTube, the selected video, iOS, or the vehicle may not offer video output. Use the playback controls inside YouTube; this app cannot create an output or change YouTube's route."
        }
    }

    static let steps = [
        "Park the vehicle safely.",
        "Connect your iPhone to a compatible CarPlay vehicle that supports AirPlay video.",
        "Open YouTube on your iPhone.",
        "Start the video you want to watch in YouTube.",
        "If YouTube offers an appropriate AirPlay output and your vehicle supports it, select the vehicle display from YouTube's playback controls.",
        "Let the vehicle and iOS enforce video availability. Video may stop or switch to audio only when unavailable."
    ]
}
