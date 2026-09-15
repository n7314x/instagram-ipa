import SwiftUI
import UIKit
import WebKit

struct MainPager: UIViewControllerRepresentable {
    @Binding var selection: InstagramSection
    let webViews: WebViewPool

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, webViews: webViews)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        context.coordinator.pager = pager

        if let scrollView = pager.view.subviews.compactMap({ $0 as? UIScrollView }).first {
            scrollView.isDirectionalLockEnabled = true
            scrollView.alwaysBounceVertical = false
            scrollView.delaysContentTouches = false
        }

        let initial = context.coordinator.controller(for: selection)
        pager.setViewControllers([initial], direction: .forward, animated: false)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.navigateIfNeeded(to: selection)
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var selection: Binding<InstagramSection>
        let webViews: WebViewPool
        weak var pager: UIPageViewController?
        var visibleSection: InstagramSection
        var isTransitioning = false
        private var pendingSelection: InstagramSection?
        private var controllers: [InstagramSection: WebPageViewController] = [:]

        init(selection: Binding<InstagramSection>, webViews: WebViewPool) {
            self.selection = selection
            self.visibleSection = selection.wrappedValue
            self.webViews = webViews
        }

        func controller(for section: InstagramSection) -> WebPageViewController {
            if let existing = controllers[section] { return existing }
            let controller = WebPageViewController(
                section: section,
                webView: webViews.webView(for: section)
            )
            controllers[section] = controller
            return controller
        }

        func navigateIfNeeded(to section: InstagramSection) {
            guard section != visibleSection else { return }
            guard !isTransitioning else {
                pendingSelection = section
                return
            }
            guard let pager else { return }

            let direction: UIPageViewController.NavigationDirection =
                section.rawValue > visibleSection.rawValue ? .forward : .reverse
            isTransitioning = true
            pager.setViewControllers(
                [controller(for: section)],
                direction: direction,
                animated: !UIAccessibility.isReduceMotionEnabled
            ) { [weak self] _ in
                guard let self else { return }
                self.visibleSection = section
                self.isTransitioning = false
                self.performPendingNavigation()
            }
        }

        private func performPendingNavigation() {
            guard let pendingSelection else { return }
            self.pendingSelection = nil
            navigateIfNeeded(to: pendingSelection)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let current = viewController as? WebPageViewController,
                  let previous = InstagramSection(rawValue: current.section.rawValue - 1) else { return nil }
            return controller(for: previous)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let current = viewController as? WebPageViewController,
                  let next = InstagramSection(rawValue: current.section.rawValue + 1) else { return nil }
            return controller(for: next)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            isTransitioning = true
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            isTransitioning = false
            if completed,
               let visible = pageViewController.viewControllers?.first as? WebPageViewController {
                visibleSection = visible.section
                if pendingSelection == nil {
                    selection.wrappedValue = visible.section
                }
            }
            performPendingNavigation()
        }
    }
}

@MainActor
final class WebPageViewController: UIViewController {
    let section: InstagramSection
    private let webView: WKWebView

    init(section: InstagramSection, webView: WKWebView) {
        self.section = section
        self.webView = webView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
