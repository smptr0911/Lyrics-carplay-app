#if targetEnvironment(simulator)
import CarPlay
import UIKit

/// Simulator-only template exploration, not a shipping CarPlay capability.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(CarPlayTemplates.root { [weak self] in
            self?.showDemoTrack()
        }, animated: false, completion: nil)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }

    private func showDemoTrack() {
        interfaceController?.pushTemplate(CarPlayTemplates.demoTrack(), animated: true, completion: nil)
    }
}
#endif
