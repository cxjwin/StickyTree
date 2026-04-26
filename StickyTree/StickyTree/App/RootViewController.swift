import UIKit
import StickyTreeCore

final class RootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sticky Tree Demo"
        view.backgroundColor = .systemBackground

        // 让 nav bar 始终不透明,避免 cell 滚到 nav bar 底下时透过 translucent 露出来
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance

        installOrgSample()
    }

    private func installOrgSample() {
        let config = StickyTreeConfig<OrgItem>(
            isBranch: { OrgRenderer.isBranch($0) },
            title:    { OrgRenderer.title(for: $0) },
            subtitle: { OrgRenderer.subtitle(for: $0) }
        )
        let vc = StickyTreeViewController<OrgItem>(
            initialSnapshot: OrgSampleData.makeSnapshot(),
            config: config,
            pinViewProvider: { OrgRenderer.makePin(for: $0, instr: $1) },
            cellProvider: { OrgRenderer.configure(cell: $0, for: $1, level: $2, isExpanded: $3) }
        )
        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
    }
}
